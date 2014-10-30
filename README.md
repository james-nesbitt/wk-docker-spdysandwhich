Based on a concept POC presented here:
[https://amsterdam2014.drupal.org/session/spdy-sandwich-superfly-sites-nginx-and-varnish](https://amsterdam2014.drupal.org/session/spdy-sandwich-superfly-sites-nginx-and-varnish)

The concept for this box is that you can put any number of instances of this container in front of any web-service that you have, and it will act as an accelerator that can efficiently handle large volumes of traffic.
The goal is to have the image work automatically, if you set some ENV variables and a LINK to the backend server.

## Github 
- [https://github.com/james-nesbitt/wk-docker-spdysandwhich](https://github.com/james-nesbitt/wk-docker-spdysandwhich)
- [https://github.com/james-nesbitt/wk-docker-spdysandwhich/wiki](https://github.com/james-nesbitt/wk-docker-spdysandwhich/wiki)

## How to use this image?

**Right now you can't.  It does not yet work!!!!!**

When it is ready. you will use it like this:

    docker run -d --link {your web container}:varnishtarget jamesnesbitt/wk-spdysandwhich

If you want to specify host ports, do so for the http and https ports on this new container:

        docker run -d --link {your web container}:varnishtarget -p 80:80 -p 443:443 jamesnesbitt/wk-spdysandwhich

## What this image does

This box is meant to start a new container, that uses nginx to receive http/https/spdy requests, and with a number of tricks (including using varnish caching) it will accelerate any single www backend.  The backend is configured using the --link function, meaning that it only currently accelerates another container.
Conceptually, you would start this container, linking it to the actuall www service, but proxy/redirect all web traffic to this container for the acceleration.

Credit goes to everybody else, I am just packaging this up right now.
