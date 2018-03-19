FROM scratch
EXPOSE 8080
ENTRYPOINT ["/golang-http-master"]
COPY ./bin/ /