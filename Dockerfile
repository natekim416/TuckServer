# Use the pre-built image from Docker Hub
FROM natekim416/tuckserver:latest

# Railway will set the PORT environment variable
EXPOSE 8080
CMD ["sh","-c","./TuckServer serve --env production --hostname 0.0.0.0 --port ${PORT:-8080}"]
