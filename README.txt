An AS3 Flash port of the marvelous Polygon Clipping library by Angus Johnson. 
http://www.angusj.com/delphi/clipper.php

This AS3 port was created by Chris Denham <c.m.denham:gmail.com>
The translation is derived directly from the Clipper Library C# version as 
at version 4.8.8, available from the above address. This AS3 port may not be 
complete in some respects, and has not had extensive testing, but it does 
function correctly for simple examples tried so far. Also beware that this 
port only uses 32 bit integer arithmetic whereas the original C# code uses 
64 and 128 bit integer arithmetic. This means you will need to restrict
poly vertex coordinates for this implementation to 16 bit range.
Suggestions for changes and fixes are welcomed, though not necessarily acted upon. ;-)

This port was originally inspired by the AS3 Flash module written by 
Ari Arnbjörnsson < ari@flassari.is > that wraps the Clipper library 
more directly via Adobe Alchemy/FlasCC, which can be downloaded from:
https://github.com/Flassari/as3clipper
Ari's Alchemy based wrapper may offer more completeness and better performance, 
but beware of potential licensing restrictions imposed by Adobe for content using 
so called "Premium Features" (which appears to include FlasCC), for info:
http://www.adobe.com/devnet/flashplayer/articles/premium-features-licensing-faq.html