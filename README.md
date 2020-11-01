# Docker 를 이용한 간단한 React App.

create-react-app 을 기반으로 docker 를 이용하여 개발 및 배포.

## Getting Started

## Docker
```shell script
docker-compose up
```

### Start
```shell script
npm run start
```

### Test
```shell script
npm run test
```

### Build
```shell script
npm run build
```

## Docker 를 이용하여 개발단계에서 리액트 실행하기

Dockerfile 을 개발단계를 위한것과 실제 배포 후를 위한 것을 따로 작성하는것이 좋다.
개발단계에서 사용할 Dockerfile 을 Dockerfile.dev 로 만든다. 

```shell script
docker build ./

# failed to solve with frontend dockerfile.v0: failed to read dockerfile
```

명령어 실행시 에러가 발생한다. 이는 해당 디렉토리 내에 Dockerfile 을 자동으로 찾아오는데
현재 개발을 위한 Dockerfile 은 Dockerfile.dev 로 생성되어 있어 에러가 발생한다.

에러를 해결하기 위한 방법은 임의로 빌드를 할때 docker build . 으로 하는게 아니라
`-f` 옵션으로 참조해야 하는 docker file 의 이름명을 지정해준다.

```shell script
docker build -f Dockerfile.dev -t kkangil/react-app ./
```

docker 를 이용해서 개발할 경우 local 에 node_modules 폴더는 갖고 있을 필요가 없다.
- docker image build 할때 npm install 을 하기 떄문
- docker build 성능에도 좋지않다. (Dockerfile 의 COPY ./ ./ 때문 -> node_modules 폴더의 파일까지 전부 복사함.)

리액트앱도 마찬가지로 실행시 네트워크 port 를 연결해줘야 한다. 주의해야 할 점은 리액트 앱을 실행할때 `-it` 
를 붙여야만 실행이 된다.

 ```shell script
 docker run -it -p 3000:3000 kkangil/react-app
 ```

## Docker volume 을 이용한 소스코드 변경

COPY 를 사용하면 실시간으로 바뀌지 않고 변경사항이 있을때마다 build 를 해줘야하는 
불편한 점을 volume 을 사용해서 해결할 수 있다.

```shell script
docker run -it -p 3000:3000 -v /usr/src/app/node_modules -v $(pwd):/usr/src/app kkangil/react-app
```

현재 디렉토리의 폴더와 파일을 /usr/src/app 내부에서 참조한다.
node_modules 폴더가 없기 때문에 해당 폴더는 참조하지 말라고 앞에 명시해준다.

## Docker compose 로 간단하게 실행하기

volume 을 사용해서 명령어를 입력할 경우 명령어가 너무 길어 불편한점을 Compose 를 사용하여 해소할 수 있다.

```yaml
version: 3 # 도커 컴포즈의 버전
services: # 이곳에 실행하려는 컨테이너들을 정의
  react: # 컨테이너 이름
    build: # 현 디렉토리에 있는 Dockerfile 사용
      context: . # 도커 이미지를 구성하기 위한 파일과 폴더들이 있는 위치
      dockerfile: Dockerfile.dev # 도커 파일 어떤 것이지 지정
    ports: # 포트 맵핑 로컬포트:컨테이너 포트
    - "3000:3000"
    volumes: # 로컬 머신에 있는 파일들 맵핑
    - /usr/src/app/node_modules
    - ./:/usr/src/app
    stdin_open: true # 리액트 앱을 끌때 필요(버그 수정)
```

```shell script
docker-compose up
```

## Docker 에서 리액트 앱 테스트 하기

```shell script
docker build -f dockerfile.dev .
docker run -it kkangil/react-app npm run test
```

### 테스트 소스 바로 반영되게 하기

테스트 코드를 추가하면 명령어를 다시 실행해 주는 것이 아닌 volume 을 이용해서 실시간으로 반영되게 하기

```yaml
tests:
    build:
      context: .
      dockerfile: Dockerfile.dev
    volumes:
    - /usr/src/app/node_modules
    - ./:/usr/src/app
    command: ["npm", "run", "test"]
```

service 에 compose 설정을 추가해줬다.

```shell script
docker-compose up
```

## 운영환경 도커 이미지를 위한 Dockerfile 작성하기

운영환경의 도커파일은 Dockerfile 로 생성한다.

Dockerfile 과 Dockerfile.dev 의 차이점은 CMD 밖에 없다.

```dockerfile
# Dockerfile.dev
CMD ["npm", "run", "start"]

# Dockerfile
CMD ["npm", "run", "build"]
```

build 후 생기는 build 폴더를 Nginx 를 사용하여 정적파일을 제공해준다. (Nginx 도커 이미지를 이용한 Nginx 시작)

즉, 실제 운영 환경의 도커(리액트)는 build 폴더를 만들기를 위한 목적으로 사용된다.

```dockerfile
FROM node:alpine as builder

WORKDIR /usr/src/app

COPY package.json ./

RUN npm install

COPY ./ ./

RUN npm run build

FROM nginx

COPY --from=builder /usr/src/app/build /usr/share/nginx/html
```
- `as builder` 는 해당 FROM 부터 다음 FROM 까지 builder stage 부분이라는 것을 명시
- --from=builder: 다른 Stage 에 있는 파일을 복사할때 다룬 Stage 이름을 명시
- /usr/src/app/build /usr/share/nginx/html : build stage 에서 생성된 파일들은 해당 폴더로 들어가게 되며 그곳에 저장된
                                           파일들을 /usr/share/nginx/html 로 복사를 시켜줘서 nginx 가 웹 브라우저의
                                            http 이 올때마다 알맞은 파일을 전해 줄 수 있게 한다.
- /usr/share/nginx/html : 이 장소로 build 파일들을 복사 시켜주는 이유는 이 장소로 파일을 넣어두면 Nginx 가 알아서
                         Clinet 에서 요청이 들어올때 알맞은 정적 파일들을 제공해 줌. 설정을 통해서 변경도 가능.

### 운영환경 Dockerfile 요약

1. 빌드 파일들을 생성한다. (Builder Stage)
2. Nginx 를 가동하고 첫번째 단계에서 생성된 빌드폴더의 파일들을 웹 브라우저의 요청에 따라 제공해준다. (Run Stage)

```shell script
docker run -p 8080:80 kkangil/react-app
```

Nginx 의 기본 포트가 80 이기 때문에 80 으로 맵핑해준다.
