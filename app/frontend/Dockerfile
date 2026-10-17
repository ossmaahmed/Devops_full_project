FROM nginxinc/nginx-unprivileged:stable-alpine

COPY index.html app.js styles.css /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
