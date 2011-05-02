DBD::Oracle SUB-specific README

So far mot much to but here but here is one hint


If you get this on a Solaris 9 and 10 box

  "Outofmemory!
   Callback called exit.
   END failed--call queue aborted."

The solution may be as simple as not having you "ORACLE_HOME" Defined in the enviornment.

Seems as long as it defined it will stop the above error.

Thanks to Rich White for figuring this out and Jim McCullars fr sugessting I make this README for sun
 
 

