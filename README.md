# MSBuild + IncrementalClean

This illustrates an MSBuild problem we are trying to figure out with
Xamarin.Android.

See [MSBuild Github Issues #3916](https://github.com/Microsoft/msbuild/issues/3916).

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

There should be plenty of `*.binlog` files to look through in the current directory.

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

# Solution

I don't know if this is the ideal solution, but it works. I will look
into making this changes in Xamarin.Android, so we will see how that
goes.

## What to do for `Build`?

We can use `$([MSBuild]::Unescape())` in combination with
`$(CoreBuildDependsOn)`:

```xml
<CoreBuildDependsOn>
  $([MSBuild]::Unescape($(CoreBuildDependsOn.Replace('IncrementalClean;', '_CompileDex;IncrementalClean;'))))
</CoreBuildDependsOn>
```

In this case `Build` will run `_CompileDex` *before*
`IncrementalClean` and everything works.

### Concerns

It seems a bit nasty, but works...

The only problem I see:

* If a target was named `FooIncrementalClean`, this might break...

The original value of `$(CoreBuildDependsOn)` is:
```

      BuildOnlySettings;
      PrepareForBuild;
      PreBuildEvent;
      ResolveReferences;
      PrepareResources;
      ResolveKeySource;
      Compile;
      ExportWindowsMDFile;
      UnmanagedUnregistration;
      GenerateSerializationAssemblies;
      CreateSatelliteAssemblies;
      GenerateManifests;
      GetTargetPath;
      PrepareForRun;
      UnmanagedRegistration;
      IncrementalClean;
      PostBuildEvent
    
```
_Empty newline in front, six spaces starting each line._

So we could always replace " IncrementalClean;" with a space in front,
I don't know if that is better/worse.

## What to do for `SignAndroidPackage`?

So we need `IncrementalClean` to run after the work in
`SignAndroidPackage` is done.

So to achieve this:

* Moved the actual work in `SignAndroidPackage` to a
  `_SignAndroidPackage` target. The `SignAndroidPackage` target is
  empty.
* Created a new `_AdjustCoreBuildDependsOn` target to remove
  `IncrementalClean` from `$(CoreBuildDependsOn)`.
  `$([MSBuild]::Unescape())` is required.
* `SignAndroidPackage` now depends on
  `_AdjustCoreBuildDependsOn;_SignAndroidPackage;IncrementalClean`
* Everything works!

### Concerns

Only concern it is a little messy, but seems like a reasonable
solution?