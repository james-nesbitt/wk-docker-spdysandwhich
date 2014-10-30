# Customized VCL file for serving a Drupal site.
# Wunderkraut / 2013

# Settings for a request that determines if the backend is alive and well.
probe healthcheck {
   .url = "/_ping.php";
   .interval = 5s;
   .timeout = 1s;
   .window = 5;
   .threshold = 3;
   .initial = 3;
   .expected_response = 200;
}

# Web backend definition.  Set this to point to your content server.
backend default {
  .host = "127.0.0.1";
  .port = "8889";
  .connect_timeout = 0s;
  .first_byte_timeout = 600s;
  .between_bytes_timeout = 600s;
  .probe = healthcheck;
}

# Define the internal network access.
# These are used below to allow internal access to certain files
# from offices while not allowing access from the public internet.
acl internal {
  # localhost
  "127.0.0.1";
}

# List of upstream proxies we trust to set X-Forwarded-For correctly.
acl upstream_proxy {
  "127.0.0.1";
}

sub vcl_recv {

  // Add a unique header containing the client address
  if (client.ip ~ upstream_proxy && req.http.X-Forwarded-For) {
    set req.http.X-Forwarded-For = req.http.X-Forwarded-For;
  } else {
    set req.http.X-Forwarded-For = client.ip;
  }

  if (req.request != "GET" && req.request != "HEAD") {
    /* We only deal with GET and HEAD by default */
    return (pass);
  }

  if (req.url == "/monit-check-url-happy") {
    error 200 "Varnish up";
  }

  # Healthy backend may be locked for 30s from request.
  # Sick may serve directly from cache for a few hours.
  if (req.backend.healthy) {
    set req.grace = 120s;
  }
  else {
    set req.grace = 2h;
  }

  // No varnish for ping file (for monitoring tools)
  if (req.url ~ "_ping.php") {
    return (pass);
  }

  if (req.url ~ "\.(png|gif|jpg|tif|tiff|ico|swf|css|js|pdf|doc|xls|ppt|zip)(\?.*)?$") {
    // Forcing a lookup with static file requests
    return (lookup);
  }

  # Do not allow public access to cron.php , update.php or install.php.
  if (req.url ~ "^/(cron|install|update)\.php$" && !client.ip ~ internal) {
    # Have Varnish throw the error directly.
    error 404 "Page not found.";
  }

  # Do not cache these paths.
  if (req.url ~ "^/update\.php$" ||
      req.url ~ "^/install\.php$" ||
      req.url ~ "^/cron\.php$" ||
      req.url ~ "^/ooyala/ping$" ||
      req.url ~ "^/admin/build/features" ||
      req.url ~ "^/info/.*$" ||
      req.url ~ "^/flag/.*$" ||
      req.url ~ "^.*/ajax/.*$" ||
      req.url ~ "^.*/ahah/.*$" ||
      req.url ~ "^/radioactivity_node.php$") {
       return (pass);
  }

  if (req.http.Cookie) {
    if (req.url ~ "\.(png|gif|jpg|tif|tiff|ico|swf|css|js|pdf|doc|xls|ppt|zip|woff|eot|ttf)$") {
      # Static file request do not vary on cookies
      unset req.http.Cookie;
    }
    elseif (req.http.Cookie ~ "(SESS[a-z0-9]+)") {
      # Authenticated users should not be cached
      return (pass);
    }
    else {
      # Non-authenticated requests do not vary on cookies
      unset req.http.Cookie;
    }
  }

  if (req.http.Accept-Encoding) {
    if (req.url ~ "\.(jpg|png|gif|tif|tiff|ico|gz|tgz|bz2|tbz|mp3|ogg|swf|zip|pdf|woff|eot|ttf)(\?.*)?$") {
        # No point in compressing these
        unset req.http.Accept-Encoding;
    } elsif (req.http.Accept-Encoding ~ "gzip") {
        set req.http.Accept-Encoding = "gzip";
    } elsif (req.http.Accept-Encoding ~ "deflate") {
        set req.http.Accept-Encoding = "deflate";
    } else {
        # unkown algorithm
        unset req.http.Accept-Encoding;
    }
  }
  // Keep multiple cache objects to a minimum
  unset req.http.Accept-Language;
  unset req.http.user-agent;

}

sub vcl_fetch {

  # Store the request url in cached item
  # See "Smart banning" https://www.varnish-software.com/static/book/Cache_invalidation.html
  set beresp.http.x-url = req.url;

  # gzip is by default on for (easily) compressable transfer types
  if (beresp.http.content-type ~ "text/html" || beresp.http.content-type ~ "css" || beresp.http.content-type ~ "javascript") {
    set beresp.do_gzip = true;
  }

  # Default TTL for all content is 12h
  set beresp.ttl = 12h;

  if (req.url ~ "\.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|flv|swf|html|htm|otf|json)\??.*$") {
    # Strip any cookies before static files are inserted into cache.
    unset beresp.http.set-cookie;
    if(beresp.status == 200){
      set beresp.ttl = 7d;
      set beresp.http.isstatic = "1";
    } else{
      # Dont cache broken images etc for more than 30s, and not at all clientside.
      set beresp.ttl = 30s;
      set beresp.http.Cache-control = "max-age=0, must-revalidate";
    }
  }

  if (beresp.status == 404) {
    if (beresp.http.isstatic) {
      /*
       * 404s for static files might include profile data since they're actually Drupal pages.
       * See sites/default/settings.php for how 404s are implemented "the fast way"
       */
      set beresp.ttl = 0s;
    }
  }

  # Allow items to be stale if needed.
  set beresp.grace = 2h;

}

sub vcl_deliver {
  if (obj.hits > 0) {
    set resp.http.X-Varnish-Cache = "HIT";
  }
  else {
    set resp.http.X-Varnish-Cache = "MISS";
  }

  # See https://www.varnish-cache.org/trac/wiki/VCLExampleLongerCaching
  if (resp.http.magicmarker) {
    unset resp.http.magicmarker; # Remove the magic marker
    set resp.http.age = "0"; # By definition we have a fresh object
  }

  if (resp.http.isstatic) {
    unset resp.http.isstatic;
  }

  unset resp.http.X-Varnish;
  unset resp.http.Via;
  unset resp.http.Server;
  unset resp.http.X-Powered-By;
  unset resp.http.x-do-esi;
  unset resp.http.X-Forced-Gzip;
  unset resp.http.X-Generator;

  # Remove the request url from the cached item's headers
  # See "Smart banning" https://www.varnish-software.com/static/book/Cache_invalidation.html
  unset resp.http.x-url;
}

sub vcl_error {
    set obj.http.Content-Type = "text/html; charset=utf-8";
    set obj.http.Retry-After = "10";
    synthetic {"
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
<title>Error loading the page</title>

</head>

<body>
  <div id="error-box">
    &nbsp
    <div id="error-message">
      <h1>Our best people are on the case!</h1>
      <h2>Please check back shortly</h2>
      <h3>Error loading the page</h3>
    </div>
  </div>

  <script type="text/javascript">
    var _gaq = _gaq || [];
    _gaq.push(['_setAccount', 'SET_ACCOUNT_HERE']); _gaq.push(['_trackPageview']);
    _gaq.push(['_trackEvent', 'Errors', '"} + obj.status + {"', '"} + obj.response +
        " | " + req.http.X-Session-String + " | " + req.request + {" "']);
    (function() { var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true; ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js'; var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s); })();
  </script>
  <!--"} + obj.status + " " + obj.response + {"-->

</body>
</html>
"};
    return (deliver);
}

sub vcl_hash {
  # URL and hostname/IP are the default components of the vcl_hash implementation.
  # We add more below.
  hash_data(req.url);
  if (req.http.host) {
    hash_data(req.http.host);
  } else {
    hash_data(server.ip);
  }

  # Include the X-Forwarded-Proto header, since we want to treat HTTPS requests differently,
  # and make sure this header is always passed properly to the backend server.
  if (req.http.X-Forwarded-Proto) {
    hash_data(req.http.X-Forwarded-Proto);
  }

  return (hash);
}
