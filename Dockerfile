# Builder Stage

# 해당 FROM 부터 다음 FROM 까지 builder stage 부분이라는 것을 명시
FROM node:alpine as builder

WORKDIR /usr/src/app

COPY package.json ./

RUN npm install

COPY ./ ./

RUN npm run build

FROM nginx

# nginx port mapping 을 해주지 않으면 EB 에러 발생
EXPOSE 80

COPY --from=builder /usr/src/app/build /usr/share/nginx/html

# --from=builder: 다른 Stage 에 있는 파일을 복사할때 다룬 Stage 이름을 명시
# /usr/src/app/build /usr/share/nginx/html : build stage 에서 생성된 파일들은 해당 폴더로 들어가게 되며 그곳에 저장된
#                                           파일들을 /usr/share/nginx/html 로 복사를 시켜줘서 nginx 가 웹 브라우저의
#                                            http 이 올때마다 알맞은 파일을 전해 줄 수 있게 한다.
# /usr/share/nginx/html : 이 장소로 build 파일들을 복사 시켜주는 이유는 이 장소로 파일을 넣어두면 Nginx 가 알아서
#                         Clinet 에서 요청이 들어올때 알맞은 정적 파일들을 제공해 줌. 설정을 통해서 변경도 가능.
