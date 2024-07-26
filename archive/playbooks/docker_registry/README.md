# docker_registry

This playbook gets 2 docker registries running as docker containers.

The first registry is for publishing images.
The second registry is used as a pull-through cache (as we are unable to push images to a mirror).

Additionally the reverse proxy configuration is included to easy access on the network.

Finally, other hosts on the network running docker are set up to use it as a pull-through cache.
