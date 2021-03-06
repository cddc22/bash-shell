#!/bin/sh
 
# 最好在执行完lnmp_for_el7.sh后，在使用本脚本覆盖安装nginx，最好不要直接使用本脚本（直接使用的话我没有测试）
# CentOS 7默认使用openssl 1.0.1，但是这个版本不支持ALPN, 详见： http://nginx.org/en/docs/http/ngx_http_v2_module.html#issues
# 但是nginx 1.10.0以后，只有HTTP/2模块，不再有spdy，并且除chrome外的浏览器都必须支持ALPN才能开启HTTP/2
# 本脚本用于在CentOS 7上编译openssl 1.0.2并且重新编译nginx（除openssl外其他配置和官方版本一样）
# 编译选项参考： http://nginx.org/en/linux_packages.html#arguments

WORKING_DIR="$PWD";
OPENSSL_PREFIX_DIR=/usr/local/openssl-1.1.1;
OPENSSL_VERSION=1.1.1d;
OPENSSL_BUILD_OPTIONS=("--release" "no-deprecated" "no-dso" "no-shared"
        "no-tests" "no-external-tests" "no-external-tests" 
        "no-aria" "no-bf" "no-blake2" "no-camellia" "no-cast" "no-idea" 
        "no-md2" "no-md4" "no-mdc2" "no-rc2" "no-rc4" "no-rc5" "no-hw" "no-ssl3");
NGINX_VERSION=1.16.1;

OPENSSL_DIR_NAME="openssl-$OPENSSL_VERSION";
OPENSSL_PKG_NAME="$OPENSSL_DIR_NAME.tar.gz";
NGINX_DIR_NAME="nginx-$NGINX_VERSION";
NGINX_PKG_NAME="$NGINX_DIR_NAME.tar.gz";


# 软件源
yum repolist | grep "\\bepel\\b" ;
if [ 0 -ne $? ]; then
  yum install epel-release ;
fi
yum repolist | grep "\\bnginx\\b" ;
if [ 0 -ne $? ]; then
  rpm -ivh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm ;
fi

# 安装依赖项
yum install -y gcc gdb make automake gcc-c++ libtool yum-utils yum-plugin-remove-with-leaves yum-cron yum-plugin-upgrade-helper yum-plugin-fastestmirror rpm-build;
yum-builddep -y nginx;

# 下载openssl
if [ ! -e "$OPENSSL_PKG_NAME" ]; then
    wget "https://www.openssl.org/source/$OPENSSL_PKG_NAME";
fi

tar -axvf "$OPENSSL_PKG_NAME";
if [ ! -e "$OPENSSL_PREFIX_DIR" ]; then
    cd "$OPENSSL_DIR_NAME";
    ./config --prefix="$OPENSSL_PREFIX_DIR" ${OPENSSL_BUILD_OPTIONS[@]};
    make ; # -j;
    make install;
    cd - ;
fi

# build nginx
if [ ! -e "$NGINX_PKG_NAME" ]; then
    wget "http://nginx.org/download/$NGINX_PKG_NAME";
fi

tar -axvf "$NGINX_PKG_NAME";
cd "$NGINX_DIR_NAME";

# 编译选项参考： http://nginx.org/en/linux_packages.html#arguments

./configure \
  --prefix=/etc/nginx \
  --sbin-path=/usr/sbin/nginx \
  --modules-path=/usr/lib64/nginx/modules \
  --conf-path=/etc/nginx/nginx.conf \
  --error-log-path=/var/log/nginx/error.log \
  --http-log-path=/var/log/nginx/access.log \
  --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock \
  --http-client-body-temp-path=/var/cache/nginx/client_temp       \
  --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
  --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
  --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
  --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
  --user=nginx \
  --group=nginx \
  --with-compat \
  --with-file-aio \
  --with-threads \
  --with-http_addition_module \
  --with-http_auth_request_module \
  --with-http_dav_module \
  --with-http_flv_module \
  --with-http_gunzip_module \
  --with-http_gzip_static_module \
  --with-http_mp4_module \
  --with-http_random_index_module \
  --with-http_realip_module \
  --with-http_secure_link_module \
  --with-http_slice_module \
  --with-http_ssl_module \
  --with-http_stub_status_module \
  --with-http_sub_module \
  --with-http_v2_module \
  --with-mail \
  --with-mail_ssl_module \
  --with-stream \
  --with-stream_realip_module \
  --with-stream_ssl_module \
  --with-stream_ssl_preread_module \
  --with-cc-opt='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -m64 -mtune=generic -fPIC' \
  --with-ld-opt='-Wl,-z,relro -Wl,-z,now -pie' \
  --with-openssl="$WORKING_DIR/$OPENSSL_DIR_NAME" \
  --with-openssl-opt="-fPIC" ;

make ; # -j;
make install;
