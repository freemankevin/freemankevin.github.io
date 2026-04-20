# Build stage
FROM node:20-alpine AS builder

WORKDIR /app
COPY . .

RUN npm install \
    && npm run build

# Runtime stage
FROM nginx:alpine

COPY --from=builder /app/public /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"] 