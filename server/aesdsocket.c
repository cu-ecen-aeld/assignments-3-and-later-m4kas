#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <syslog.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>


#define ELEMENTS_PER_ONE_READ   (512u)
const char *file_path = "/var/tmp/aesdsocketdata";
FILE *file = NULL;
int socket_id = -1;
int client_socket = -1;
volatile unsigned char server_working = 1;
unsigned char file_openned = 0;

static void signal_handler(int signal_number)
{
    if ((signal_number == SIGTERM) || (signal_number == SIGINT))
    {
        if (client_socket != -1)
        {
            close(client_socket);
        }
        if (socket_id != -1)\
        {
            close(socket_id);
        }
        if ((file != NULL) && (file_openned == 1))
        {
            fclose(file);
            file_openned = 0;
        }
        remove(file_path);
        //printf("Caught signal, exiting\n");
        syslog(LOG_ERR, "Caught signal, exiting");
        server_working = 0;
    }
}

int main(int argc, char **argv)
{
    openlog(NULL, 0, LOG_USER);

    struct sigaction signal_action;
    memset(&signal_action, 0, sizeof(sigaction));
    signal_action.sa_handler = signal_handler;

    unsigned char daemon_mode = 0;
    if ((argc > 1) && (strcmp(argv[1], "-d") == 0))
    {
        daemon_mode = 1;
    }

    if (sigaction(SIGTERM, &signal_action, NULL) != 0)
    {
        syslog(LOG_ERR, "Error registering signal SIGTERM");
        exit(-1);
    }
    if (sigaction(SIGINT, &signal_action, NULL) != 0)
    {
        syslog(LOG_ERR, "Error registering signal SIGINT");
        exit(-1);
    }

    struct addrinfo hints;
    memset((void *)&hints, 0, sizeof(hints));
    hints.ai_flags = AI_PASSIVE;
    struct addrinfo *servinfo;

    int status;
    if ((status = getaddrinfo(NULL, "9000", &hints, &servinfo)) != 0)
    {
        syslog(LOG_ERR, "getaddrinfo error");
        exit(-1);
    }
    else
    {
        //printf("getaddrinfo success\n");
    }

    if  ((socket_id = socket(PF_INET, SOCK_STREAM, 0)) == -1)
    {
        syslog(LOG_ERR, "socket error");
        exit(-1);
    }
    else
    {
        //printf("socket() success\n");
    }

    int bind_status = 0;
    if ((bind_status = bind(socket_id, servinfo->ai_addr, sizeof(struct sockaddr))) != 0)
    {
        syslog(LOG_ERR, "bind error, result code: %d, errno: %d", bind_status, errno);
        exit(-1);
    }

    if (daemon_mode)
    {
        if (fork() > 0)
        {
            // Exiting parent program
            ////printf("Exiting parent program\n");
            exit(0);
        }
    }

    if (listen(socket_id, 1) != 0)
    {
        syslog(LOG_ERR, "listen error");
        exit(-1);
    }
    else
    {
        //printf("listen() success\n");
    }
    server_working = 1;

    while (1)
    {
        if (server_working == 0)
        {
            break;
        }
        struct sockaddr client_sockaddr;
        memset((void *)&client_sockaddr, 0, sizeof(client_sockaddr));
        socklen_t socklen = sizeof(client_sockaddr);
        if ((client_socket = accept(socket_id, &client_sockaddr, &socklen)) == -1)
        {
            syslog(LOG_ERR, "accept error");
            exit(-1);
        }
        syslog(LOG_INFO, "Accepted connection from %s", client_sockaddr.sa_data);
        //printf("Accepted connection from %s\n", client_sockaddr.sa_data);

        //printf("Before file open, errno: %d\n", errno);
        file = fopen(file_path, "a+");
        if (file == NULL)
        {
            //printf("Failed to open file, errno: %d\n", errno);
            syslog(LOG_ERR, "Failed to open file");
            return errno;
        }
        else
        {
            file_openned = 1;
            //printf("File open success\n");
        }

        while (1)
        {
            if (server_working == 0)
            {
                break;
            }
            unsigned char buf[ELEMENTS_PER_ONE_READ];
            memset(&buf, 0, ELEMENTS_PER_ONE_READ);
            int elements_read = recv(client_socket, buf, ELEMENTS_PER_ONE_READ, MSG_DONTWAIT);
            //printf("number read: %d\n", elements_read);
            // No errors and certain number of elements have been read
            if (elements_read > 0)
            {
                //printf("Elements to read: %d\n", elements_read);
                fseek(file, 0, SEEK_END);
                (void)fwrite(buf, 1, elements_read, file);
                if(strchr(buf, '\n') != NULL)
                {
                    // packet complete found, writing whole file to the client
                    unsigned char read_buf[ELEMENTS_PER_ONE_READ];
                    int num_read = 0;
                    //printf("Newline found in message\n");
                    fseek(file, 0, SEEK_SET);
                    while ((num_read = fread(read_buf, 1, ELEMENTS_PER_ONE_READ, file)) != 0)
                    {
                        send(client_socket, read_buf, num_read, 0);
                        memset(&read_buf, 0, ELEMENTS_PER_ONE_READ);
                        //fseek(file, num_read, SEEK_SET);
                    }
                }
            }
            else if (elements_read == 0)
            {
                // Client disconnected
                //printf("Client dropped, closing the file\n");
                fclose(file);
                file_openned = 0;
                break;
            }
        }
    }
    freeaddrinfo(servinfo);
    return 0;
}