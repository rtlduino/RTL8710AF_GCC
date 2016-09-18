#ifndef	__ytcpsocketDotH__
#define	__ytcpsocketDotH__

#ifdef	__cplusplus
	extern "C" {
#endif

        void ytcpsocket_set_block(int socket,int on);
        int ytcpsocket_connect(const char *host,int port,int timeout);
        int ytcpsocket_close(int socketfd);
        int ytcpsocket_pull(int socketfd,char *data,int len);
        int ytcpsocket_send(int socketfd,const char *data,int len);
        int ytcpsocket_listen(const char *addr,int port);
        int ytcpsocket_accept(int onsocketfd,char *remoteip,int* remoteport);
        

#ifdef	__cplusplus
	}
#endif

#endif	// __ytcpsocketDotH__
