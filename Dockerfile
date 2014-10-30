#
# Multiline runs are used to minimize RUN transactions to keep the cache
# shorter for this basebox.  There is no need to overdo the caching here.
#
FROM            centos:centos7
MAINTAINER      james.nesbitt@wunderkraut.com

## EPEL Dependency on CentOS 7 and Fedora EPEL 7 ##
RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 && \
    rpm --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7 && \
    rpm -Uvh https://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-2.noarch.rpm

# Update and clean
RUN /usr/bin/yum update -y

# Install some tools used here.
RUN /usr/bin/yum install -y hostname

# NGINX will want to use PCRE and OPENSSL
RUN /usr/bin/yum install -y openssl pcre

# Install nginx
ADD nginx-1.7.7-1.spdy+pagespeed19_noinit.el7.centos.x86_64.rpm /root/nginx-1.7.7-1.spdy+pagespeed19_noinit.el7.centos.x86_64.rpm
RUN /usr/bin/yum install -y yum --nogpgcheck localinstall /root/nginx-1.7.7-1.spdy+pagespeed19_noinit.el7.centos.x86_64.rpm
ADD etc/nginx/nginx.conf /etc/nginx/nginx.conf
ADD etc/nginx/conf.d /etc/nginx/conf.d
EXPOSE 80 443

# Install varnish (make it run as the nginx user)
RUN /usr/bin/yum install -y varnish
ADD etc/varnish /etc/varnish
# Should we expose the varnish port?
EXPOSE 6081

# Install supervisord
RUN /usr/bin/yum install -y supervisor
ADD etc/supervisord.d /etc/supervisord.d
EXPOSE 9001

# Command that will run when the server starts
USER root
CMD /usr/bin/supervisord --nodaemon --configuration /etc/supervisord.conf
