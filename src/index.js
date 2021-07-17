require('dotenv').config()
const app = require('express')()
const server = require('http').createServer(app)
const io = require('socket.io')(server)
const yaml = require('js-yaml')
const fs = require('fs')
const config = yaml.load(fs.readFileSync(process.env.CONFIG_FILE, 'utf8'))
const readline = require('readline')
const suffix_list_file_path = '/tmp/public_suffix_list.dat'

const detect_publicsuffix = target => {
    const fileStream = fs.createReadStream(suffix_list_file_path)
    const rl = readline.createInterface({
        input: fileStream,
        crlfDelay: Infinity
    })
    const suffixes = new Set()
    for (const line of rl) {
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

app.set('port', process.env.SOCKETS_PORT || config.app.default_port || 5080)

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
        delete data.socket_key
        io.sockets.in(client_token).emit('domain_changes', data)
    })

    socket.on('dns_changes', json => {
        let data = json
        if (typeof json === "string") {
            data = JSON.parse(json)
        }
        const client_token = data.socket_key
        delete data.socket_key
        io.sockets.in(client_token).emit('dns_changes', data)

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
            const suffix = detect_publicsuffix(domain)
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
app.get('/healthcheck', (_, res) => {
    res.status(200).send("ok")
})
server.listen(app.get('port'), () => {
    fs.writeFile('/srv/app/nodemon.pid', process.pid.toString(), err => {
        if (err) throw err
    })
    console.log(`listening on *:${app.get('port')}`)
})
