module:depends("http_upload")

-- imports
local st     = require "util.stanza"
local base64 = require "util.encodings".base64
local lfs    = require "lfs"
local uuid   = require "util.uuid".generate

local function join_path(a, b)
    return a .. package.config:sub(1,1) .. b
end

local function err(e_stanza, error_type, text)
    local error_stanza = st.error_reply(e_stanza, "modify", error_type, text)
    module:send(error_stanza)
    return true
end

-- vars
local download_path = module:get_option_string("http_external_url", module:http_url():gsub("(//.*/).*$", "%1")):gsub("/$", "")..module:get_option_string(module.name.."_url", "/upload")
module:log("debug", "Download path: "..download_path)

local storage_path = module:get_option_string("http_upload_path", join_path(prosody.paths.data, "http_upload"))
local file_size_limit = module:get_option_number("http_upload_file_size_limit", 1024 * 1024) -- 1 MB



local function on_message(event)
    if event.stanza.attr.type == "error" then
        return
    end

    -- get image or voice
    local bin = event.stanza:get_child("image", "http://mangga.me/protocol/image")
    if not bin then
        bin = event.stanza:get_child("voice", "http://mangga.me/protocol/voice")
    end
    if not bin then
        return
    end

    -- match content-type
    local ext = ""
    if bin.attr and bin.attr.type == "image/jpeg" then
        ext = ".jpg"
    elseif bin.attr and bin.attr.type == "audio/voice" then
        ext = ".m4a"
    end


    bin = base64.decode(bin:get_text())
    if not bin then
        module:log("error", "Invalid base64")
        return err(event.stanza, "bad-request", "Invalid base64 encoded image")
    end

    -- remove big image tag
    event.stanza:maptags(function(child) 
        if child.name == "image" or child.name == "voice" or child.name == "body" then
            return nil
        end
        return child
    end)

    local len = bin:len()
    if len > file_size_limit then
        module:log("error", "Uploaded file too large: %d bytes", len)
        return err(event.stanza, "not-acceptable", "File size too large: "..len.." bytes, max ".. file_size_limit/1024 .. " kilobytes allowed")
    end

    local random = uuid()

    local dirname = join_path(storage_path, random)
    local ok, err = lfs.mkdir(dirname)
    if not ok then
        module:log("error", "Could not create directory %s for upload: %s", dirname, err)
        return err(event.stanza, "internal-server-error", err)
    end
    local filename = uuid() .. ext
    local full_filename = join_path(dirname, filename)
    local fh, err = io.open(full_filename, "w")
    if not fh then
        module:log("error", "Could not open file %s for upload: %s", full_filename, err)
        return err(event.stanza, "internal-server-error", err)
    end
    ok, err = fh:write(bin)
    bin = nil
    if not ok then
        module:log("error", "Could not write to file %s for upload: %s", full_filename, err)
        os.remove(full_filename)
        return err(event.stanza, "internal-server-error", err)
    end
    ok, err = fh:close()
    if not ok then
        module:log("error", "Could not write to file %s for upload: %s", full_filename, err)
        os.remove(full_filename)
        return err(event.stanza, "internal-server-error", err)
    end

    module:log("info", "Image saved to %s", full_filename)

    local url = download_path .. "/" .. random .. "/" .. filename
    event.stanza:body(url):up()
    event.stanza:tag("x", { xmlns = "jabber:x:oob" })
    event.stanza:tag("url"):text(url)
    return
end

-- process early, so that bloated stanza doesn't get archived, etc.
module:hook("pre-message/bare", on_message, 20)
module:hook("pre-message/full", on_message, 20)
module:hook("pre-message/host", on_message, 20)
module:hook("message/bare", on_message, 20)
module:hook("message/full", on_message, 20)
module:hook("message/host", on_message, 20)
