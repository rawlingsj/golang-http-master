FROM scratch
EXPOSE 8080
COPY ./bin/ /
CMD ['golang-http-master']