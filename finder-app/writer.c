#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <syslog.h>

int main(int argc, char **argv)
{
    openlog(NULL, 0, LOG_USER);

    /* First parameter (#0) is filename */
    if (argc != 3)
    {
        syslog(LOG_ERR, "Please provide 2 arguments (%d provided)", argc - 1);
        return 1;
    }

    FILE *file = fopen(argv[1], "w");

    if ((file == NULL) || errno != 0)
    {
        syslog(LOG_ERR, "Failed to open file");
        return errno;
    }




    fprintf(file, "%s", argv[2]);

    if (errno != 0)
    {
        syslog(LOG_ERR, "Error writing to the file");
        return errno;
    }

    return 0;
}