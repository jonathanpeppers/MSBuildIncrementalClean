Remove-Item .\bin -Recurse
Remove-Item .\obj -Recurse

$project = '.\Foo.csproj'
$args = '/nologo'
$verbosity = '/v:quiet'
& msbuild $project $verbosity $args /t:Build /bl:first.binlog
& msbuild $project $verbosity $args /t:Build /bl:second.binlog
& msbuild $project $verbosity $args /t:SignAndroidPackage /bl:package.binlog

# May uncomment this to see how the Clean target behaves
#& msbuild $project $verbosity $args /t:Clean /bl:clean.binlog