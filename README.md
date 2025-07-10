# lua env autoconfig for lua-resty-acme
```bash
luarocks install --dev autossl
```

## usage
```
env DOMAINS;
env DIR;
env ACCOUNT_KEY;
end STAGING;
env EXPIRE_DAYS;

http {
  init_by_lua_block {
    require("resty.acme.autossl").init( require('autossl'):config() )
  }
}
```

## nginx.conf example from lua-resty-acme combined with autossl
```
env DOMAINS;
env DIR;
env ACCOUNT_KEY;
end STAGING;
env EXPIRE_DAYS;

events {}
http {
  resolver 8.8.8.8 ipv6=off;
  lua_shared_dict acme 16m;

  # required to verify Let's Encrypt API
  lua_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;
  lua_ssl_verify_depth 2;

  init_by_lua_block {
    require("resty.acme.autossl").init( require('autossl'):config() )
  }

  init_worker_by_lua_block {
    require("resty.acme.autossl").init_worker()
  }

  server {
    listen 80;
    listen 443 ssl;
    server_name example.com;

    # fallback certs, make sure to create them before hand
    ssl_certificate /etc/ssl/default.pem;
    ssl_certificate_key /etc/ssl/default.key;

    ssl_certificate_by_lua_block {
      require("resty.acme.autossl").ssl_certificate()
    }

    location /.well-known {
      content_by_lua_block {
        require("resty.acme.autossl").serve_http_challenge()
      }
    }
  }
}
```

## env
* `DOMAINS`: list of domains (mask `*.example.com` accepted), any delimeter
  * server hostname is probed if no `DOMAINS` var set
* `DIR`: /etc/keys by default, supposed to be docker mounted volume
* `ACCOUNT_KEY`: account key in PEM format or new key
* `STAGING`: 1/0, true/false
* `EXPIRE_DAYS`: number

## args
Arguments from `lua-resty-acme` accepted by `autossl:config()` method.

## more examples
```
  init_by_lua_block {
    require("resty.acme.autossl").init(require('autossl'):config({
      staging = true,
      domain_whitelist_callback = function(domain, is_new_cert_needed)
        return ngx.re.match(domain, [[\.example\.com$]], "jo")
      end,
    }))
  }
```

## depends on
* `https://github.com/zhaozg/lua-openssl`

## inspired by
* `https://github.com/fffonion/lua-resty-acme`

## todo
* use storages
* more options
