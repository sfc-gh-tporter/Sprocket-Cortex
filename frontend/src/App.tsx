import { ChainringLogo } from './components/ChainringLogo'
import { Sidebar } from './components/Sidebar'
import { ChatPanel } from './components/ChatPanel'
import { useChat } from './hooks/useChat'
import { useBikeContext } from './hooks/useBikeContext'

export default function App() {
  const {
    bikes,
    selectedBikeId,
    setSelectedBikeId,
    components,
    maintenance,
    loadingContext,
  } = useBikeContext()

  const { messages, streaming, sendMessage, reset } = useChat(selectedBikeId)

  const handleSelectBike = (id: string | null) => {
    setSelectedBikeId(id)
    reset()
  }

  return (
    <div className="flex h-screen overflow-hidden">
      <aside className="w-[300px] min-w-[300px] bg-carbon-900 border-r border-carbon-700 flex flex-col p-5">
        {/* Header */}
        <div className="flex items-center gap-3 mb-6 pb-4 border-b border-carbon-700">
          <ChainringLogo size={42} />
          <div>
            <h1 className="text-xl font-bold text-[#f0fdf4]">Sprocket</h1>
            <span className="text-[11px] text-muted block mt-0.5">Bike Maintenance AI</span>
          </div>
        </div>

        <Sidebar
          bikes={bikes}
          selectedBikeId={selectedBikeId}
          onSelectBike={handleSelectBike}
          components={components}
          maintenance={maintenance}
          loadingContext={loadingContext}
        />
      </aside>

      <ChatPanel messages={messages} onSend={sendMessage} streaming={streaming} />
    </div>
  )
}
