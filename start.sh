docker build -t dokcer-buildx .
docker run --rm -v "$(pwd)"/dist:/dist dokcer-buildx
ls -al "$(pwd)"/dist
