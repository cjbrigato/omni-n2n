/**
 * (C) 2022 - instantvpn.io and contributors
 * (C) 2007-22 ntop.org and contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.    See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not see see <http://www.gnu.org/licenses/>
 *
 */

#include "n2n.h"
#include <stdbool.h>

#ifndef INSTANT_COMMUNITY
#error "Compiling without ARG0_COMMUNITY need define INSTANT_COMMUNITY"
#endif

#define STRINGIZE(x) #x
#define STRINGIZE_VALUE_OF(x) STRINGIZE(x)

// forward declaration for use in main()
void send_register_super(n2n_edge_t *eee);
void send_query_peer(n2n_edge_t *eee, const n2n_mac_t dst_mac);
int supernode_connect(n2n_edge_t *eee);
int supernode_disconnect(n2n_edge_t *eee);
int fetch_and_eventually_process_data(n2n_edge_t *eee, SOCKET sock,
                                      uint8_t *pktbuf, uint16_t *expected, uint16_t *position,
                                      time_t now);
int resolve_check(n2n_resolve_parameter_t *param, uint8_t resolution_request, time_t now);
int edge_init_routes(n2n_edge_t *eee, n2n_route_t *routes, uint16_t num_routes);

size_t b64_encoded_size(size_t inlen)
{
    size_t ret;

    ret = inlen;
    if (inlen % 3 != 0)
        ret += 3 - (inlen % 3);
    ret /= 3;
    ret *= 4;

    return ret;
}

const char b64chars[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
char *b64_encode(const unsigned char *in, size_t len)
{
    char *out;
    size_t elen;
    size_t i;
    size_t j;
    size_t v;

    if (in == NULL || len == 0)
        return NULL;

    elen = b64_encoded_size(len);
    out = malloc(elen + 1);
    out[elen] = '\0';

    for (i = 0, j = 0; i < len; i += 3, j += 4)
    {
        v = in[i];
        v = i + 1 < len ? v << 8 | in[i + 1] : v << 8;
        v = i + 2 < len ? v << 8 | in[i + 2] : v << 8;

        out[j] = b64chars[(v >> 18) & 0x3F];
        out[j + 1] = b64chars[(v >> 12) & 0x3F];
        if (i + 1 < len)
        {
            out[j + 2] = b64chars[(v >> 6) & 0x3F];
        }
        else
        {
            out[j + 2] = '=';
        }
        if (i + 2 < len)
        {
            out[j + 3] = b64chars[v & 0x3F];
        }
        else
        {
            out[j + 3] = '=';
        }
    }

    return out;
}

static void daemonize()
{
    int childpid;
    traceEvent(TRACE_NORMAL, "parent process is exiting (this is normal)");
    signal(SIGPIPE, SIG_IGN);
    signal(SIGHUP, SIG_IGN);
    signal(SIGCHLD, SIG_IGN);
    signal(SIGQUIT, SIG_IGN);
    if ((childpid = fork()) < 0)
        traceEvent(TRACE_ERROR, "occurred while daemonizing (errno=%d)",
                   errno);
    else
    {
        if (!childpid)
        { /* child */
            int rc;
            rc = chdir("/");
            if (rc != 0)
                traceEvent(TRACE_ERROR, "error while moving to / directory");
            setsid(); /* detach from the terminal */
            fclose(stdin);
            fclose(stdout);
            setvbuf(stdout, (char *)NULL, _IOLBF, 0);
        }
        else /* father */
            exit(0);
    }
}

static int keep_on_running;

#if defined(__linux__)
static void term_handler(int sig)
{
    static int called = 0;

    if (called)
    {
        traceEvent(TRACE_NORMAL, "ok, I am leaving now");
        _exit(0);
    }
    else
    {
        traceEvent(TRACE_NORMAL, "shutting down...");
        called = 1;
    }

    keep_on_running = 0;
}
#endif /* defined(__linux__) || defined(WIN32) */

int main(int argc, char *argv[])
{
    int rc;
    tuntap_dev tuntap;            /* a tuntap device */
    n2n_edge_t *eee;              /* single instance for this program */
    n2n_edge_conf_t conf;         /* generic N2N edge config */
    n2n_tuntap_priv_config_t ec;  /* config used for standalone program execution */
    uint8_t runlevel = 0;         /* bootstrap: runlevel */
    uint8_t seek_answer = 1;      /* expecting answer from supernode */
    time_t now, last_action = 0;  /* timeout */
    macstr_t mac_buf;             /* output mac address */
    fd_set socket_mask;           /*            for supernode answer */
    struct timeval wait_time;     /*            timeout for sn answer */
    peer_info_t *scan, *scan_tmp; /*            supernode iteration */
    uint16_t expected = sizeof(uint16_t);
    uint16_t position = 0;
    uint8_t pktbuf[N2N_SN_PKTBUF_SIZE + sizeof(uint16_t)]; /* buffer + prepended buffer length in case of tcp */
    struct passwd *pw = NULL;

    edge_init_conf_defaults(&conf);
    memset(&ec, 0, sizeof(ec));
    ec.mtu = DEFAULT_MTU;
    ec.daemon = 0;

    if ((pw = getpwnam("nobody")) != NULL)
    {
        ec.userid = pw->pw_uid;
        ec.groupid = pw->pw_gid;
    }

    snprintf(ec.tuntap_dev_name, sizeof(ec.tuntap_dev_name), N2N_EDGE_DEFAULT_DEV_NAME);
    snprintf(ec.netmask, sizeof(ec.netmask), N2N_EDGE_DEFAULT_NETMASK);
    strncpy((char *)conf.community_name, STRINGIZE_VALUE_OF(INSTANT_COMMUNITY), N2N_COMMUNITY_SIZE);
    conf.community_name[N2N_COMMUNITY_SIZE - 1] = '\0';
    char *enc;
    enc = b64_encode((const unsigned char *)conf.community_name, strlen(conf.community_name));
    if (conf.encrypt_key)
        free(conf.encrypt_key);
    conf.encrypt_key = strdup(enc);

    traceEvent(TRACE_NORMAL, "starting edge %s %s", PACKAGE_VERSION, PACKAGE_BUILDDATE);
    traceEvent(TRACE_NORMAL, "using compression: %s.", compression_str(conf.compression));
    if (edge_conf_add_supernode(&conf, "supernode-a.instantvpn.io:7777") != 0)
    {
        traceEvent(TRACE_WARNING, "failed to add supernode '%s'", "supernode-a.instantvpn.io:7777");
    }
    conf.transop_id = N2N_TRANSFORM_ID_AES;
    traceEvent(TRACE_NORMAL, "using %s cipher.", transop_str(conf.transop_id));

    n2n_srand(n2n_seed());
    if (setuid(0) != 0)
        traceEvent(TRACE_ERROR, "unable to become root [%u/%s]", errno, strerror(errno));
    /* setgid(0); */

    if ((eee = edge_init(&conf, &rc)) == NULL)
    {
        traceEvent(TRACE_ERROR, "failed in edge_init");
        exit(1);
    }

    memcpy(&(eee->tuntap_priv_conf), &ec, sizeof(ec));

    traceEvent(TRACE_NORMAL, "automatically assign IP address by supernode");
    eee->conf.tuntap_ip_mode = TUNTAP_IP_MODE_SN_ASSIGN;

    runlevel = 2;
    eee->last_sup = 0; /* if it wasn't zero yet */
    eee->curr_sn = eee->conf.supernodes;
    supernode_connect(eee);
    while (runlevel < 5)
    {

        now = time(NULL);
        if (runlevel == 2)
        { 
                last_action = now;
                eee->sn_wait = 1;
                send_register_super(eee);
                runlevel++;
                traceEvent(TRACE_NORMAL, "send REGISTER_SUPER to supernode [%s] asking for IP address",
                           eee->curr_sn->ip_addr);
        }

        if (runlevel == 3)
        { /* REGISTER_SUPER to get auto ip address from a sn has been sent */
            if (!eee->sn_wait)
            { /* TUNTAP IP address received */
                runlevel++;
                traceEvent(TRACE_NORMAL, "received REGISTER_SUPER_ACK from supernode for IP address asignment");
                // it should be from curr_sn, but we can't determine definitely here, so no details to output
            }
            else if (last_action <= (now - BOOTSTRAP_TIMEOUT))
            {
                // timeout, so try next supernode
                if (eee->curr_sn->hh.next)
                    eee->curr_sn = eee->curr_sn->hh.next;
                else
                    eee->curr_sn = eee->conf.supernodes;
                supernode_connect(eee);
                runlevel--;
                // skip waiting for answer to direcly go to send REGISTER_SUPER again
                seek_answer = 0;
                traceEvent(TRACE_DEBUG, "REGISTER_SUPER_ACK timeout");
            }
        }

        if (runlevel == 4)
        { /* configure the TUNTAP device, including routes */
            if (tuntap_open(&tuntap, eee->tuntap_priv_conf.tuntap_dev_name, eee->tuntap_priv_conf.ip_mode,
                            eee->tuntap_priv_conf.ip_addr, eee->tuntap_priv_conf.netmask,
                            eee->tuntap_priv_conf.device_mac, eee->tuntap_priv_conf.mtu) < 0)
                exit(1);
            memcpy(&eee->device, &tuntap, sizeof(tuntap));
            traceEvent(TRACE_NORMAL, "created local tap device IP: %s, Mask: %s, MAC: %s",
                       eee->tuntap_priv_conf.ip_addr,
                       eee->tuntap_priv_conf.netmask,
                       macaddr_str(mac_buf, eee->device.mac_addr));
            // routes
            if (edge_init_routes(eee, eee->conf.routes, eee->conf.num_routes) < 0)
            {
                traceEvent(TRACE_ERROR, "routes setup failed");
                exit(1);
            }
            runlevel = 5;
            // no more answers required
            seek_answer = 0;
        }

        // we usually wait for some answer, there however are exceptions when going back to a previous runlevel
        if (seek_answer)
        {
            FD_ZERO(&socket_mask);
            FD_SET(eee->sock, &socket_mask);
            wait_time.tv_sec = BOOTSTRAP_TIMEOUT;
            wait_time.tv_usec = 0;

            if (select(eee->sock + 1, &socket_mask, NULL, NULL, &wait_time) > 0)
            {
                if (FD_ISSET(eee->sock, &socket_mask))
                {

                    fetch_and_eventually_process_data(eee, eee->sock,
                                                      pktbuf, &expected, &position,
                                                      now);
                }
            }
        }
        seek_answer = 1;

        resolve_check(eee->resolve_parameter, 0 /* no intermediate resolution requirement at this point */, now);
    }
    eee->conf.number_max_sn_pings = NUMBER_SN_PINGS_INITIAL;
    // shape supernode list; make current one the first on the list
    HASH_ITER(hh, eee->conf.supernodes, scan, scan_tmp)
    {
        if (scan == eee->curr_sn)
            sn_selection_criterion_good(&(scan->selection_criterion));
        else
            sn_selection_criterion_default(&(scan->selection_criterion));
    }
    sn_selection_sort(&(eee->conf.supernodes));
    eee->last_sweep = now - SWEEP_TIME + 2 * BOOTSTRAP_TIMEOUT;
    eee->sn_wait = 1;
    eee->last_register_req = 0;

    if (eee->tuntap_priv_conf.daemon)
    {
        setUseSyslog(1);
        daemonize();
    }
    if ((eee->tuntap_priv_conf.userid != 0) || (eee->tuntap_priv_conf.groupid != 0))
    {
        traceEvent(TRACE_NORMAL, "dropping privileges to uid=%d, gid=%d",
                   (signed int)eee->tuntap_priv_conf.userid, (signed int)eee->tuntap_priv_conf.groupid);
        if ((setgid(eee->tuntap_priv_conf.groupid) != 0) || (setuid(eee->tuntap_priv_conf.userid) != 0))
        {
            traceEvent(TRACE_ERROR, "unable to drop privileges [%u/%s]", errno, strerror(errno));
            exit(1);
        }
    }

    signal(SIGPIPE, SIG_IGN);
    signal(SIGTERM, term_handler);
    signal(SIGINT, term_handler);

    keep_on_running = 1;
    eee->keep_running = &keep_on_running;
    traceEvent(TRACE_NORMAL, "edge started");
    rc = run_edge_loop(eee);
    print_edge_stats(eee);

    edge_term_conf(&eee->conf);
    tuntap_close(&eee->device);
    edge_term(eee);

    return (rc);
}
