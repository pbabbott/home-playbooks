FROM semaphoreui/semaphore:latest

USER root
RUN apk add --no-cache python3 py3-pip
RUN pip install pywinrm jmespath netaddr passlib requests matrix_client

USER semaphore

COPY ./ansible_collections/requirements.yml /home/semaphore/requirements.yml
RUN ansible-galaxy collection install --upgrade -r /home/semaphore/requirements.yml
