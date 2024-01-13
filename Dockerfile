# FROM semaphoreui/semaphore:latest

# USER root
# RUN /sbin/apk add py3-pip

# USER semaphore
# RUN pip install pywinrm


FROM semaphoreui/semaphore:latest

USER root
RUN apk add --no-cache python3 py3-pip
RUN pip install pywinrm jmespath netaddr passlib requests matrix_client

USER semaphore
