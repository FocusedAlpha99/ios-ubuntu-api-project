import Terminal from './components/Terminal'
import './App.css'

function App() {
  return (
    <div className="swivel-shell">
      <section className="pane pane--left">
        <div className="pane__header">Gemini Chat (Brain)</div>
        <div className="pane__body">
          <p>Conversational planning, prompts, and analysis will live here.</p>
          <p className="placeholder">Realtime chat UI coming in next sprint.</p>
        </div>
      </section>

      <section className="pane pane--center">
        <Terminal />
      </section>

      <section className="pane pane--right">
        <div className="pane__header">Agent State / Context</div>
        <div className="pane__body">
          <ul>
            <li>Task timeline</li>
            <li>Active tools</li>
            <li>System vitals</li>
          </ul>
        </div>
      </section>
    </div>
  )
}

export default App
