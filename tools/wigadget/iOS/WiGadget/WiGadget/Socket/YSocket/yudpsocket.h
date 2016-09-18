#ifndef	__yudpsocketDotH__
#define	__yudpsocketDotH__

#ifdef	__cplusplus
	extern "C" {
#endif
        int yudpsocket_server(const char *addr,int port);
        int yudpsocket_recive(int socket_fd,char *outdata,int expted_len,char *remoteip,int* remoteport);
        int yudpsocket_close(int socket_fd);
        int yudpsocket_client();
        int yudpsocket_get_server_ip(char *host,char *ip);
        int yudpsocket_sentto(int socket_fd,char *msg,int len, char *toaddr, int topotr);
        
#ifdef	__cplusplus
	}
#endif

#endif	// __yudpsocketDotH__
