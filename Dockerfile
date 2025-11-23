FROM node:18 as builder

WORKDIR /build

# 强制国内源，避免 Yarn fallback 卡住
ENV YARN_REGISTRY=https://registry.npmmirror.com
ENV npm_config_registry=https://registry.npmmirror.com
ENV yarn_config_registry=https://registry.npmmirror.com

RUN echo "registry=https://registry.npmmirror.com" > ~/.npmrc

RUN yarn config set registry https://registry.npmmirror.com
RUN yarn config set network-timeout 600000
RUN yarn config set networkConcurrency 1

COPY web/package.json .
COPY web/yarn.lock .

RUN yarn --frozen-lockfile

COPY ./web .
COPY ./VERSION .
RUN DISABLE_ESLINT_PLUGIN='true' VITE_APP_VERSION=$(cat VERSION) npm run build


FROM golang:1.25.0 AS builder2

ENV GO111MODULE=on \
    CGO_ENABLED=1 \
    GOOS=linux \
    GOPROXY=https://goproxy.cn,https://mirrors.aliyun.com/goproxy/,https://goproxy.io,direct \
    GOSUMDB=sum.golang.google.cn

WORKDIR /build
ADD go.mod go.sum ./
RUN go mod download

COPY . .
COPY --from=builder /build/build ./web/build

RUN go build -ldflags "-s -w -X 'one-api/common.Version=$(cat VERSION)' -extldflags '-static'" -o one-api


FROM alpine

RUN apk update \
    && apk upgrade \
    && apk add --no-cache ca-certificates tzdata \
    && update-ca-certificates 2>/dev/null || true \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone

ENV TZ=Asia/Shanghai

COPY --from=builder2 /build/one-api /
EXPOSE 3000
WORKDIR /data
ENTRYPOINT ["/one-api"]
