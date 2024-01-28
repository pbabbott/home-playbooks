
# diun.platform=linux/arm64
FROM semaphoreui/semaphore:latest@sha256:47add7dba5172f9709cc251b36cbda187ca60b97bc417ce68cb182aa3e400346

USER root
RUN apk add --no-cache python3 py3-pip
RUN pip install pywinrm jmespath netaddr passlib requests matrix_client

# Issue where docker system prune is not working against room_of_requirement
# https://github.com/docker/docker-py/issues/3113#issuecomment-1531621678
RUN pip remove requests && pip install requests=2.28.1

USER semaphore
