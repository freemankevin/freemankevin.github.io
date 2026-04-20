# Build stage
FROM node:20-alpine AS builder

WORKDIR /app
COPY . .

RUN npm install \
    && npm run build

# Runtime stage
FROM nginx:alpine

COPY --from=builder /app/public /usr/share/nginx/html
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"] 