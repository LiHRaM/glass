#! /bin/bash
GOOS=`go env GOOS`
GOARCH=`go env GOARCH`
XGOARCH=$GOARCH

function run_build_daemon {
	echo "building Daemon..."
	go build -o $GOPATH/bin/glass-daemon -ldflags "-X main.Version `cat VERSION` -X main.Build `date -u +%Y%m%d%H%M%S`" ./glass-daemon
}

function run_build_cli {
	echo "building CLI..."
	go build -o $GOPATH/bin/glass -ldflags "-X main.Version `cat VERSION` -X main.Build `date -u +%Y%m%d%H%M%S`" .
}

function run_run_daemon {
	run_build_daemon
	glass-daemon -bind :10000
}  

function run_test {
	echo "running all tests..."
	go test ./...
}  

function run_build {	
	run_build_cli
	run_build_daemon
}  

function run_release_prepare_dirs {
	echo "creating release directories..."
	rm -fr bin/${GOOS}*
	mkdir -p bin/${GOOS}_${GOARCH}
	cp $GOPATH/bin/glass-daemon bin/${GOOS}_${GOARCH}
	cp $GOPATH/bin/glass bin/${GOOS}_${GOARCH}
}

function run_release {
	run_test
	run_build
	run_release_prepare_dirs
}  

#choose command
echo "Detected OS '$GOOS'"
echo "Detected Arch '$GOARCH'"
case $1 in
    "test") run_test ;;
    "build" ) run_build ;;
	"build-daemon" ) run_build_daemon ;;
	"run-daemon" ) run_run_daemon ;;
	"release" ) run_release ;;

	#
	# following commands are not portable
	# and only work on osx with "github-release"
	# "zip" and "shasum" installed and in PATH

 	# 1. zip all binaries
 	"publish-1" )
		rm -fr bin/dist
		mkdir -p bin/dist
		for FOLDER in ./bin/*_* ; do \
			NAME=`basename ${FOLDER}`_`cat VERSION` ; \
			ARCHIVE=bin/dist/${NAME}.zip ; \
			pushd ${FOLDER} ; \
			echo Zipping: ${FOLDER}... `pwd` ; \
			zip ../dist/${NAME}.zip ./* ; \
			popd ; \
		done 
		;;

	# 2. checksum zips
	"publish-2" )
		rm bin/dist/*_SHA256SUMS
		cd bin/dist && shasum -a256 * > ./timeglass_`cat ../../VERSION`_SHA256SUMS
		;;

	# 3. create tag and push it
	"publish-3" )
		git tag v`cat VERSION`
		git push --tags
		;;

	# 4. draft a new release
	"publish-4" )
		github-release release \
	    	--user timeglass \
	    	--repo glass \
	    	--tag v`cat VERSION` \
	    	--pre-release
 		;;
 		
 	# 5. upload files
	"publish-5" )
		echo "Uploading zip files..."
		for FOLDER in ./bin/*_* ; do \
			NAME=`basename ${FOLDER}`_`cat VERSION` ; \
			ARCHIVE=bin/dist/${NAME}.zip ; \
			echo "  $ARCHIVE" ; \
			github-release upload \
		    --user timeglass \
		    --repo glass \
		    --tag v`cat VERSION` \
		    --name ${NAME}.zip \
		    --file ${ARCHIVE} ; \
		    echo "done!"; \
		done
		echo "Uploading shasums..."
		github-release upload \
		    --user timeglass \
		    --repo glass \
		    --tag v`cat` \
		    --name timeglass_`cat VERSION`_SHA256SUMS \
		    --file bin/dist/timeglass_`cat VERSION`_SHA256SUMS
		echo "done!"
 		;;
	*) run_test ;;
esac