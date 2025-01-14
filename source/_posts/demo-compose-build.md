---
title: Docker Compose 构建示例
date: 2025-01-14 17:44:25
tags:
    - Development
    - Docker Compose
    - Docker
category: Development
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 本文详细介绍了使用Docker Compose构建Spring Cloud应用的完整示例，包括Java代码示例、Dockerfile配置、Nacos配置中心集成等内容。通过实际的项目结构和配置文件，展示了如何实现容器化应用的构建、部署和管理，适合开发人员参考使用。

<!-- more -->

## 项目结构

```bash
project/
├── src/
│   └── main/
│       ├── java/
│       │   └── com/
│       │       └── example/
│       │           ├── DemoApplication.java
│       │           └── controller/
│       │               └── HelloController.java
│       └── resources/
│           └── bootstrap.yml
├── docker/
│   ├── Dockerfile
│   └── nacos-config.sh
├── docker-compose.yml
└── pom.xml
```

## Java示例代码

1. DemoApplication.java:
```java
package com.example;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;

@SpringBootApplication
@EnableDiscoveryClient
public class DemoApplication {
    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }
}
```

2. HelloController.java:
```java
package com.example.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.cloud.context.config.annotation.RefreshScope;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RefreshScope
public class HelloController {
    
    @Value("${demo.message:Hello default}")
    private String message;
    
    @GetMapping("/hello")
    public String hello() {
        return message;
    }
}
```

3. bootstrap.yml:
```yaml
spring:
  application:
    name: demo-service
  cloud:
    nacos:
      config:
        file-extension: yaml
        server-addr: ${NACOS_HOST:nacos}:${NACOS_PORT:8848}
        namespace: public
      discovery:
        server-addr: ${NACOS_HOST:nacos}:${NACOS_PORT:8848}
        namespace: public
```

4. pom.xml:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>demo-service</artifactId>
    <version>1.0.0</version>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>2.3.12.RELEASE</version>
    </parent>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>com.alibaba.cloud</groupId>
            <artifactId>spring-cloud-starter-alibaba-nacos-config</artifactId>
            <version>2.2.7.RELEASE</version>
        </dependency>
        <dependency>
            <groupId>com.alibaba.cloud</groupId>
            <artifactId>spring-cloud-starter-alibaba-nacos-discovery</artifactId>
            <version>2.2.7.RELEASE</version>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```

## Docker配置

1. 更新后的Dockerfile:
```dockerfile
FROM adoptopenjdk/openjdk8:alpine-jre

WORKDIR /home

ADD ./target/*.jar ./app.jar

ENTRYPOINT [ \
    "java", \
    "-Djava.security.egd=file:/dev/./urandom", \
    "-jar", \
    "app.jar", \
    "--spring.profiles.active=dev", \
    "--spring.cloud.nacos.discovery.server-addr=127.0.0.1:8848", \
    "--spring.cloud.nacos.config.server-addr=127.0.0.1:8848", \
    "--spring.cloud.nacos.config.namespace=public", \
    "--spring.cloud.nacos.discovery.namespace=public", \
    "--spring.cloud.nacos.username=nacos", \
    "--spring.cloud.nacos.password=nacos" \
]
```

2. nacos-config.sh:
```bash
#!/bin/bash

# 等待Nacos启动
echo "Waiting for Nacos to start..."
while ! curl -s http://nacos:8848/nacos/v1/cs/configs; do
    sleep 1
done

# 导入配置
curl -X POST "http://nacos:8848/nacos/v1/cs/configs" \
    -d "dataId=demo-service.yaml" \
    -d "group=DEFAULT_GROUP" \
    -d "content=demo:
  message: Hello from Nacos Config" \
    -d "type=yaml"

echo "Nacos configuration imported successfully"
```

3. 更新docker-compose.yml:
```yaml
version: '3'

services:
  app:
    build:
      context: .
      dockerfile: docker/Dockerfile
    image: demo-service:${TAG:-latest}
    container_name: demo-service
    restart: unless-stopped
    environment:
      - TZ=Asia/Shanghai
      - NACOS_HOST=nacos
      - NACOS_PORT=8848
    ports:
      - "8080:8080"
    volumes:
      - ./logs:/home/logs
    networks:
      - app_net
    depends_on:
      - nacos

  nacos:
    image: nacos/nacos-server:2.0.3
    container_name: nacos
    environment:
      - MODE=standalone
      - TZ=Asia/Shanghai
    ports:
      - "8848:8848"
    volumes:
      - ./nacos/logs:/home/nacos/logs
      - ./nacos/conf:/home/nacos/conf
      - ./nacos/data:/home/nacos/data
    networks:
      - app_net

  nacos-config-import:
    image: curlimages/curl:7.78.0
    container_name: nacos-config-import
    volumes:
      - ./docker/nacos-config.sh:/nacos-config.sh
    command: ["sh", "/nacos-config.sh"]
    networks:
      - app_net
    depends_on:
      - nacos

networks:
  app_net:
    driver: bridge
```

## 构建和运行

1. 编译Java项目：
```bash
# 编译打包
mvn clean package -DskipTests

# 使用默认tag构建镜像
docker-compose build

# 指定tag构建镜像
TAG=v1.0 docker-compose build
```

2. 启动服务：
```bash
# 启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看服务日志
docker-compose logs -f

# 查看资源使用
docker-compose top
```

3. 验证服务：
```bash
# 测试配置是否生效
curl http://localhost:8080/hello

# 查看服务注册状态
curl http://localhost:8848/nacos/v1/ns/instance/list?serviceName=demo-service

# 检查网络连接
docker-compose exec app ping nacos
```

4. 服务管理：
```bash
# 重新构建并启动特定服务
docker-compose up -d --build app

# 扩展服务实例
docker-compose up -d --scale app=3

# 停止并移除容器
docker-compose down

# 停止并移除容器及镜像
docker-compose down --rmi all
```

## 注意事项

1. 环境准备：
   - 确保Docker Engine和Docker Compose已正确安装
   - 检查daemon.json配置是否生效
   - 确保Maven环境正确配置

2. 构建优化：
   - 使用.dockerignore排除不需要的文件
   - 使用alpine基础镜像减小体积
   - 合理使用多阶段构建
   - 优化镜像层次结构

3. 运行建议：
   - 生产环境使用固定tag
   - 合理配置资源限制
   - 定期清理未使用的镜像和容器
   - 使用depends_on确保服务启动顺序

4. 故障排查：
```bash
# 构建问题
docker-compose build --no-cache --progress=plain
docker-compose config

# 运行问题
docker-compose logs --tail=100 app
docker-compose ps
docker-compose top
```

## 总结

本示例展示了如何使用Docker Compose构建和部署Spring Cloud应用，包括Nacos配置中心的集成和自动配置导入。通过合理的项目结构和配置管理，实现了容器化应用的高效部署和管理。