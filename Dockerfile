FROM nginx:alpine

LABEL maintainer="CI-CD Practical"
LABEL description="LaunchPad project management dashboard"

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
