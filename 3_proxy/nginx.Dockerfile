FROM nginx:alpine
RUN apk update && apk add bash && apk add openssl

COPY nginx.conf /etc/nginx/nginx.conf
COPY htpasswd/ /etc/nginx/htpasswd/

