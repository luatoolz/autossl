local pkey  = require 'openssl.pkey'
local env   = require 'autossl.env'
local function maskdomains(d)
  if d:sub(1,1)=='*' then return d:sub(3,#d), d end
  return d, "*."..d
end
return {
  alt = function(a,b) if type(a)~='nil' then return a else return b end end,
  hostname = function()
    local f = io.popen("hostname")
    local hostname = f:read("*a") or ""
    f:close()
    hostname = string.gsub(hostname, "\n$", "")
    return hostname
  end,
  rsakey = function(bits)
    local rsa = pkey.new{ type = "RSA", bits = bits or 4096 }
    return rsa:toPEM('private')
  end,
  domains = function(v)
    if not v then return nil end
    local dom = {}

    if type(v)=='string' then
      for dd in string.gmatch(v, '[^%s%:%,%;]+') do
        for _,d in ipairs({maskdomains(dd)}) do
          if not dom[d] then
            dom[d]=true; table.insert(dom,d)
          end
        end
      end
    end
    if type(v)=='table' then
      for _,dd in ipairs(v) do
        for _,d in ipairs({maskdomains(dd)}) do
          if not dom[d] then
            dom[d]=true; table.insert(dom,d)
          end
        end
      end
    end
    return (dom and (#dom>0)) and dom or nil
  end,
  valid = function(d)
    d = d or {}
    local http = ngx.var.scheme=='http'
    return (http and d[ngx.var.host]) and '1' or nil
  end,
  config = function(self, r)
    self.conf = self.conf or {
      tos_accepted = true,
      renew_threshold = 7 * 86400,
      renew_check_interval = 12 * 3600,
      storage_adapter = "file",
      challenge_start_delay = 1,
      enabled_challenge_handlers = { 'http-01'},
    }
    self.var = self.var or {
      staging = function(st)
        st = st or env.staging
        return (st ~= nil) and (string.len(st) > 0) and (st ~= "0") and (st ~= "false") and (not (not st))
      end,
      host = function(alt) return env.host or alt or self.hostname() end,
      dir = function() return env.dir or '/etc/keys' end,
      expire = function() return env.expire_days or '365' end,
      domain_whitelist = function(v) return self.domains(v or env.domains) or {self.hostname()} or {} end,
      account_key_path = function(dir, name, content)
        name = name or 'account.key'
        local p = dir .. '/' .. name
        local rr = io.open(p, 'r')
        if rr then rr:close(); return p end
        content = content or env.account_key or self.rsakey(4096)
        local w = io.open(p, 'w')
        w:write(content)
        w:close()
        return p
      end,
      account_email = function(host, name) return string.format('%s@%s', name or 'root', host or self.hostname()) end,
    }
    local tocopy = type(r)~='nil'
    r = r or self.conf
    if tocopy then
      for k,v in pairs(self.conf) do
        if type(r[k])=='nil' then
          r[k]=v
        end
      end
    end

    r.storage_config      = r.storage_config or {}
    r.storage_config.dir  = r.storage_config.dir or self.var.dir()
    r.staging             = r.staging or self.var.staging()

    r.account_key_path    = r.account_key_path or self.var.account_key_path(r.storage_config.dir)
    r.domain_whitelist    = r.domain_whitelist or self.var.domain_whitelist(r.domains)
    r.account_email       = r.account_email or self.var.account_email(r.domain_whitelist[1])
    return r
  end,
}
