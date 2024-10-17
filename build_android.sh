export ANDROID_NDK_HOME=/android/android-ndk-r27
export CC=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi35-clang
CGO_ENABLED=1 GOOS=android GOARCH=arm GOARM=7 go build -o android-controler ./cmd/controller