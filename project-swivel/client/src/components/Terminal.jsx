import { useEffect, useRef } from 'react'
import { io } from 'socket.io-client'
import { Terminal as XTerm } from 'xterm'
import { FitAddon } from 'xterm-addon-fit'
import 'xterm/css/xterm.css'

const SOCKET_URL = 'http://localhost:3001'

export default function Terminal() {
  const containerRef = useRef(null)
  const termRef = useRef(null)
  const fitRef = useRef(null)
  const socketRef = useRef(null)
  const resizeObserverRef = useRef(null)

  useEffect(() => {
    if (termRef.current) {
      return
    }

    const terminal = new XTerm({
      cursorBlink: true,
      convertEol: true,
    })
    const fitAddon = new FitAddon()
    terminal.loadAddon(fitAddon)

    termRef.current = terminal
    fitRef.current = fitAddon

    if (containerRef.current) {
      containerRef.current.style.width = '100%'
      containerRef.current.style.height = '100%'
      terminal.open(containerRef.current)
      fitAddon.fit()
      terminal.focus()
    }

    const socket = io(SOCKET_URL)
    socketRef.current = socket

    const dataSubscription = terminal.onData((data) => {
      socket.emit('terminal.input', data)
    })

    socket.on('terminal.output', (data) => {
      terminal.write(data)
    })

    const handleResize = () => {
      fitAddon.fit()
    }

    window.addEventListener('resize', handleResize)

    if (typeof ResizeObserver !== 'undefined' && containerRef.current) {
      const observer = new ResizeObserver(() => {
        fitAddon.fit()
      })
      observer.observe(containerRef.current)
      resizeObserverRef.current = observer
    }

    return () => {
      window.removeEventListener('resize', handleResize)
      if (resizeObserverRef.current) {
        resizeObserverRef.current.disconnect()
        resizeObserverRef.current = null
      }
      dataSubscription.dispose()
      socket.off('terminal.output')
      socket.disconnect()
      terminal.dispose()
      termRef.current = null
      fitRef.current = null
      socketRef.current = null
    }
  }, [])

  useEffect(() => {
    if (fitRef.current) {
      fitRef.current.fit()
    }
  })

  return <div ref={containerRef} className="terminal-root" />
}
