VERSION?="1.3.2"

ifndef S3_ARTIFACTS_BUCKET
$(error S3_ARTIFACTS_BUCKET (Used as a location for saving the build zip files) was not set. exiting")
exit 1
endif

echo "Version: $(VERSION), Location: $(S3_ARTIFACTS_BUCKET)"

dockers:
	echo "Running target dockers, version: $(VERSION), Location: $(S3_ARTIFACTS_BUCKET)"
	docker build --build-arg VERSION=$(VERSION) -t opensearch-build:$(VERSION) -f Dockerfile.buid_proj .
	docker build --build-arg VERSION=$(VERSION) -t build-opensearch-dashboard:$(VERSION) -f Dockerfile.buid_proj_dash .
build:
	echo "Running target build, version: $(VERSION), Location: $(S3_ARTIFACTS_BUCKET)"
	#docker run -d -it -w /opensearch-build-$(VERSION) -v /var/run/docker.sock:/var/run/docker.sock --name build-win opensearch-build:$(VERSION) bash
	docker run -d -it -v /var/run/docker.sock:/var/run/docker.sock --name build-win opensearch-build:$(VERSION) bash
	docker exec -it  build-win bash -c 'pipenv --python /usr/bin/python3 ; ./build.sh manifests/$(VERSION)/opensearch-$(VERSION).yml --snapshot --platform windows --distribution zip'
	#docker cp build-win:/OpenSearch-$(VERSION)/distribution/archives/windows-zip/build/distributions/opensearch-min-$(VERSION)-SNAPSHOT-windows-x64.zip ./opensearch-min-$(VERSION)-SNAPSHOT-windows-x64.zip
	docker cp build-win:/opensearch-build/opensearch-build-$(VERSION)/zip/builds/opensearch/plugins ./
	docker cp build-win:/opensearch-build/opensearch-build-$(VERSION)/zip/builds/opensearch/dist ./
	zip -r opensearch-$(VERSION)-win-source.zip plugins dist
	aws s3 cp opensearch-$(VERSION)-win-source.zip $(S3_ARTIFACTS_BUCKET)
democerts:
	echo "Running target democerts, version: $(VERSION), Location: $(S3_ARTIFACTS_BUCKET)"
	docker exec -it  build-win bash -c 'mkdir /opensearch-build/opensearch/ ; unzip /opensearch-build/opensearch-build-$(VERSION)/zip/builds/opensearch/dist/opensearch-min-*.zip -d /opensearch-build/opensearch ; mv /opensearch-build/opensearch/opensearch-*/* /opensearch-build/opensearch; rm -fr /opensearch-build/opensearch/opensearch-* ;  mkdir /opensearch-build/opensearch/plugins/opensearch-security ; unzip  /opensearch-build/opensearch-build-$(VERSION)/zip/builds/opensearch/plugins/opensearch-security-*.zip -d /opensearch-build/opensearch/plugins/opensearch-security ; cd /opensearch-build/opensearch/plugins/opensearch-security/tools/ ; ./install_demo_configuration.sh -y ; zip -r opensearch-with-democerts.zip /opensearch-build/opensearch'
	docker cp build-win:/opensearch-build/opensearch/plugins/opensearch-security/tools/opensearch-with-democerts.zip ./opensearch-$(VERSION)-with-democerts.zip
	aws s3 cp opensearch-$(VERSION)-with-democerts.zip $(S3_ARTIFACTS_BUCKET)
cleancerts:
	echo "Running target cleancerts, version: $(VERSION), Location: $(S3_ARTIFACTS_BUCKET)"
	docker exec -it build-win rm -fr /opensearch/
dashboard:
	echo "Running target dashboard, version: $(VERSION), Location: $(S3_ARTIFACTS_BUCKET)"
	docker run -it -d --name dashboards-build build-opensearch-dashboard:$(VERSION) bash
	docker exec -it dashboards-build bash -c 'source /usr/share/opensearch/.bashrc ; nvm install $$node_ver ; npm i -g yarn@$$yarn_ver ; yarn osd bootstrap ; yarn build --skip-os-packages'
	docker cp dashboards-build:/home/opensearch/OpenSearch-Dashboards/target/opensearch-dashboards-$(VERSION)-SNAPSHOT-windows-x64.zip ./opensearch-dashboards-$(VERSION)-SNAPSHOT-windows-x64.zip
	aws s3 cp opensearch-dashboards-$(VERSION)-SNAPSHOT-windows-x64.zip $(ARTIFACTS_LOCATION)
dashboard-plugins:
	echo "Running target dashboard-plugins, version: $(VERSION), Location: $(S3_ARTIFACTS_BUCKET)"
	docker run -it -d --name dashboard-plugins-build build-opensearch-dashboard:$(VERSION) bash
	docker exec -it dashboard-plugins-build bash -c 'source /usr/share/opensearch/.bashrc ; nvm install $$node_ver ; npm i -g yarn@$$yarn_ver ; yarn osd bootstrap ; mkdir /home/opensearch/dash-plugins/ ;cd plugins/ ; for i in anomaly-detection security alerting index-management ; do echo "#### Starting compile dashboard plugin $$i ######";git clone --branch $(VERSION).0 https://github.com/opensearch-project/$$i-dashboards-plugin.git ; cd /home/opensearch/OpenSearch-Dashboards/plugins/$${i}-dashboards-plugin ; if [ $$i != "security" ]; then yarn osd bootstrap ; fi ; yarn build ; if [[ "$$i" == "alerting" ]]; then mv build/alertingDashboards-$(VERSION).0.zip /home/opensearch/dash-plugins/ ; else mv build/$$i-dashboards-$(VERSION).0.zip /home/opensearch/dash-plugins/; fi ; cd /home/opensearch/OpenSearch-Dashboards/plugins ; rm -fr /home/opensearch/OpenSearch-Dashboards/plugins/$${i}-dashboards-plugin ; done ; zip -r /home/opensearch/dashboard-plugins.zip /home/opensearch/dash-plugins'
	docker cp dashboard-plugins-build:/home/opensearch/dashboard-plugins.zip ./dashboard-plugins-$(VERSION).zip
	aws s3 cp dashboard-plugins-$(VERSION).zip $(S3_ARTIFACTS_BUCKET)
clean:
	docker rm -f build-win
cleandash:
	docker rm -f dashboards-build dashboard-plugins-build
opensearch: build democerts dashboard dashboard-plugins
all: dockers build democerts dashboard dashboard-plugins
cleanAll: cleandash clean
