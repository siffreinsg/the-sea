# patchright has no run-server CLI or image; server.js wraps launchServer(). Node-only.
FROM mcr.microsoft.com/playwright:v1.60.0-noble
WORKDIR /app
RUN npm install patchright@1.60.0
COPY server.js .
CMD ["node", "server.js"]
