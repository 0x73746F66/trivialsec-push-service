require('dotenv').config()
const app = require('express')()
const _url = require('url')
const http = require('http')
const https = require('https')
const server = http.createServer(app)
const io = require('socket.io')(server)
const yaml = require('js-yaml')
const fs = require('fs')
const config = yaml.safeLoad(fs.readFileSync(process.env.CONFIG_FILE, 'utf8'))
const readline = require('readline')
const suffix_list_file_path = '/tmp/public_suffix_list.dat'
const suffix_list = 'https://publicsuffix.org/list/public_suffix_list.dat'

const detect_publicsuffix = async target => {
    const fileStream = fs.createReadStream(suffix_list_file_path)
    const rl = readline.createInterface({
        input: fileStream,
        crlfDelay: Infinity
    })
    const suffixes = new Set()
    for await (const line of rl) {
        const suffix = line.trim()
        if (suffix && !suffix.startsWith('#') && target.endsWith(suffix)) {
            suffixes.add(suffix)
        }
    }
    if (suffixes.size == 0) {
        console.debug(`no suffixes ${target}`)
        return null
    }
    return Array.from(suffixes).reduce((a, b) => a.length > b.length ? a : b)
}

const download_to_file = (url, dest_path, callback) => {
    const file = fs.createWriteStream(dest_path)
    let options = {}
    options.minVersion = "TLSv1.2"
    options.maxVersion = "TLSv1.3"
    options.host = _url.parse(url).hostname
    options.path = _url.parse(url).path
    const handler = res => {
        res.pipe(file)
        file.on('finish', () => file.close(callback))
    }
    const err_handler = err => {
        console.warn(err)
    }
    if ('proxy' in config.app) {
        options.host = config.app.proxy.host
        options.port = config.app.proxy.port
        options.path = url
        options.headers = {
            Host: _url.parse(url).hostname,
            // 'Proxy-Authorization': 'Basic ' + new Buffer(`${username}:${password}`).toString('base64')
        }
        http.get(options, handler).on('error', err_handler).end()
    } else if (url.startsWith('https')) {
        https.get(options, handler).on('error', err_handler).end()
    } else if (url.startsWith('http')) {
        http.get(options, handler).on('error', err_handler).end()
    }
}

app.set('port', process.env.PORT || config.app.default_port || 5080)

io.on('connection', socket => {
    socket.on('disconnect', data => {
        console.log(`client disconnect ${data}`)
    })

    socket.on('checkin', token => {
        socket.join(token)
        console.log(`checkin from ${token}`)
    })
    
    socket.on('update_job_state', json => {
        let data = json
        if (typeof json === "string") {
            data = JSON.parse(json)
        }
        const token = data.socket_key
        delete data.socket_key
        io.sockets.in(token).emit('update_job_state', data)
    })
    
    socket.on('domain_changes', json => {
        let data = json
        if (typeof json === "string") {
            data = JSON.parse(json)
        }
        const client_token = data.socket_key
        const project_token = data.project_tracking_id
        delete data.socket_key
        delete data.project_tracking_id
        if (project_token) {
            io.sockets.in(project_token).emit('domain_changes', data)
        } else if (client_token) {
            io.sockets.in(client_token).emit('domain_changes', data)
        }
    })

    socket.on('dns_changes', json => {
        let data = json
        if (typeof json === "string") {
            data = JSON.parse(json)
        }
        const client_token = data.socket_key
        const project_token = data.project_tracking_id
        delete data.socket_key
        delete data.project_tracking_id
        if (project_token) {
            io.sockets.in(project_token).emit('dns_changes', data)
        } else if (client_token) {
            io.sockets.in(client_token).emit('dns_changes', data)
        }

    })

    // socket.on('update_service_state', json => {
    //     let data = json
    //     if (typeof json === "string") {
    //         data = JSON.parse(json)
    //     }
    //     delete data.job
    //     io.sockets.emit('update_service_state', data)
    // })

    socket.on('check_service_state', json => {
        let data = json
        if (typeof json === "string") {
            data = JSON.parse(json)
        }
        const token = data.socket_key
        delete data.socket_key
        data.response = 'idle'
        io.sockets.in(token).emit('check_service_state', data)
    })

    socket.on('check_domains_tld', async json => {
        let data = json
        if (typeof json === "string") {
            data = JSON.parse(json)
        }
        const token = data.socket_key
        delete data.socket_key
        const domains = new Set()
        for await (const t of data.targets) {
            let domain = t.target.trim()
            const suffix = await detect_publicsuffix(domain)
            if (suffix) {
                let pattern = new RegExp(`\.${suffix}$`)
                let parts = domain.replace(pattern, '').split('.')
                domains.add(`${parts.pop()}.${suffix}`)
            }
        }
        data.domains = Array.from(domains).sort()
        io.sockets.in(token).emit('check_domains_tld', data)
    })
})
app.get('/healthcheck', (req, res) => {
    res.status(200).send("ok")
})
server.listen(app.get('port'), () => {
    fs.writeFile('/srv/app/nodemon.pid', process.pid.toString(), err => {
        if (err) throw err
    })
    console.log(`listening on *:${app.get('port')}`)
    download_to_file(suffix_list, suffix_list_file_path, () => {
        console.log(`✅ ${suffix_list}`)
    })
})
