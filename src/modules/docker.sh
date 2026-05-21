MODULE_NAME="Docker"
MODULE_DESCRIPTION="Stopped containers, dangling images, build cache, and unused networks. Volumes are NEVER touched."
MODULE_RISK="medium"
MODULE_CATEGORY="dev"
MODULE_PATHS=("$HOME/Library/Containers/com.docker.docker/Data/log")
MODULE_COMMAND="docker container prune -f && docker image prune -f && docker builder prune -f && docker network prune -f"
MODULE_REQUIRES="docker"
MODULE_NOTES="Volumes are explicitly excluded. Running containers are not affected."
