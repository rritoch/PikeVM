#include "/includes/mudlib.h"

void add_item(mixed ... items) 
{  
    if ( mappingp(items[-1]) ) {
        ((program)SIMPLE_OB)(items[-1], items[0..<2]);    
    } else {
 
      if ( items[-1][-1] != '\n' ) {
          items[-1] += "\n";
      }
  
      ((program)SIMPLE_OB)( (["look":items[-1] ]),items[0..<2]);
    }
}