
private int intensity;

final void light_set_light(int x)
{
    int old_intensity = intensity;
    object env = environment();

    intensity = x;

    if ( env ) {
        env->containee_light_changed(x - old_intensity);
    }
}

void set_light(int x) 
{
	light_set_light(x);
}

void adjust_light(int x)
{
    object env = environment();

    intensity += x;

    if ( env ) {
        env->containee_light_changed(x);
    }
}

int query_light()
{
    return intensity;
}
