# MSBuild + IncrementalClean

This illustrates an MSBuild problem we are trying to figure out with
Xamarin.Android.

We have a few targets that run after `Build`, for example:

* `_GenerateJava` - takes `Foo.dll` -> `Foo.java` in `$(IntermediateOutputPath)`
* `_CompileJava` - takes `Foo.java` -> `Foo.jar` in `$(IntermediateOutputPath)`
* `_CompileDex` - takes `Foo.jar` -> `Foo.dex` in `$(IntermediateOutputPath)`

_NOTE: these are simplified for illustration_

We have another target, `SignAndroidPackage`, that only runs when an
APK needs to be produced. It depends on `Build`.

`SignAndroidPackage` - takes `Foo.dll;Foo.dex` -> `Foo.apk`  in
`$(OutputPath)`

## Try the example

Run:

    .\build.ps1

Ensure you have `MSBuild.exe` in your `%PATH%`, you can optionally uncomment a call to the `Clean` target.

## Problems

How do we organize these targets The Right Way™?

We are trying to get these intermediate items added to `FileWrites`
appropriately.

Issues:

1. Since `_CompileDex` and friends run after `Build`, they are running
    *after* `IncrementalClean`. They will not be present in
    `FileListAbsolute.txt`. a. We can workaround this with
    `BeforeTargets="IncrementalClean;_CleanGetCurrentAndPriorFileWrites"`.
    Is this the best option?
2. Since `SignAndroidPackage` is generally invoked by IDEs directly,
   it may/may not get run. How should we get `$(OutputPath)*.apk` into
   `FileWrites`? In a way a future `Build` would preserve it?
3. `Clean` isn't going to clean all these files, unless they were
   added to `FileWrites` appropriately, and exist in
   `FileListAbsolute.txt`.
4. There does not appear to be a `$(IncrementalCleanDependsOn)`:
   [Microsoft.Common.CurrentVersion.targets](https://github.com/Microsoft/msbuild/blob/aec1703e63f3e32ac12dd6946ba94a2b37bded63/src/Tasks/Microsoft.Common.CurrentVersion.targets#L4829-L4831)