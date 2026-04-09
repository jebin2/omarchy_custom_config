function docker-nuke
    echo "⚠️  FULL DOCKER WIPE INITIATED"
    echo "--------------------------------"

    docker stop (docker ps -q) 2>/dev/null; or true
    docker rm -f (docker ps -aq) 2>/dev/null; or true
    docker rmi -f (docker images -q) 2>/dev/null; or true
    docker volume rm (docker volume ls -q) 2>/dev/null; or true
    docker network rm (docker network ls -q) 2>/dev/null; or true
    docker builder prune -af

    echo
    echo "✅ Docker cleanup complete"
    docker system df
end
