.PHONY: deploy build tag push

build:
	docker build . -t ${IMG_NAME}:${TAG}

tag:
	docker tag ${IMG_NAME}:${TAG} ${REPO}/${IMG_NAME}:${TAG}

push:
	docker push ${REPO}/${IMG_NAME}:${TAG}

deploy:
	kubectl apply -f ./ 

run:
	docker run -it -p 8000:3000 -e USER=garybowers -u 1001 ${REPO}/${IMG_NAME}:${TAG}
