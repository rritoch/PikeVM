
#include <command.h>

int main(int argc, array(string) argv, mixed env)
{
	string name;
  string arg = argv * " "; 
	array(object) list;
	int j;
        
	printf("%-25s idle\n", "name (*edit, +input)");
	printf("--------------------      ----\n");
	for (list = users(), j = 0; j < sizeof(list); j++) {
		
		name = functionp(list[j]->query_userid) ? list[j]->query_userid() : "(Someone)";
		
		printf("%-25s %4d\n", name +
		(in_edit(this_player()) ? "*" : "") +
		(in_input(this_player()) ? "+" : ""),
		query_idle(this_player()) / 60
		);
	}
	return 1;
}