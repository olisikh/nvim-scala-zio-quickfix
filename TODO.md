
# TODOs:

1. How to reliably wait for metals to get fully initialized before making lsp requests
2. How to trigger diagnostics rebuild after "undo", sometimes after code-action diagnostic never shows up
3. Add hints that promote usage of:
    * .bimap 
    * .when 
    * .unless 
    * .exitCode 
    * .zipLeft 
    * .zipRight 
    * .delay 
    * .foreach 
    * .foreachPar
    * .tap/.tapError/.tapBoth
4. Add a hint if forgot to use a combinator like *> (zipRight), as this is very likely a developer mistake


Take ideas from successful Intellij IDEA plugin made by Igal Tabachnik:  
https://plugins.jetbrains.com/plugin/13820-zio-for-intellij/features
