## For testing

flutter build appbundle --no-tree-shake-icons
bundletool build-apks --bundle=build/app/outputs/bundle/release/app-release.aab --output=my_app.apks --local-testing
bundletool install-apks --apks=my_app.apks

dart run lib/tools/gen_colors.dart  