import { Bike, Component, MaintenanceItem } from '../types'

interface SidebarProps {
  bikes: Bike[]
  selectedBikeId: string | null
  onSelectBike: (id: string | null) => void
  components: Component[]
  maintenance: MaintenanceItem[]
  loadingContext: boolean
}

type Tab = 'bike' | 'service'

import { useState } from 'react'

export function Sidebar({
  bikes,
  selectedBikeId,
  onSelectBike,
  components,
  maintenance,
  loadingContext,
}: SidebarProps) {
  const [tab, setTab] = useState<Tab>('bike')

  const upcoming = maintenance.filter((m) => m.status !== 'done')
  const done = maintenance.filter((m) => m.status === 'done')

  return (
    <aside className="w-[300px] min-w-[300px] bg-carbon-900 border-r border-carbon-700 flex flex-col p-5">
      {/* Bike picker */}
      <div className="mb-5">
        <label className="block text-[11px] text-muted uppercase tracking-[0.8px] font-semibold mb-2">
          Active Bike
        </label>
        <select
          className="w-full px-3 py-2.5 bg-carbon-800 border border-carbon-600 rounded-lg text-sm text-gray-200 focus:outline-none focus:border-emerald-dark cursor-pointer"
          value={selectedBikeId ?? ''}
          onChange={(e) => onSelectBike(e.target.value || null)}
        >
          {bikes.length === 0 && <option value="">Loading bikes...</option>}
          {bikes.map((b) => (
            <option key={b.bike_id} value={b.bike_id}>
              {b.display_name}
            </option>
          ))}
        </select>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 mb-5 bg-carbon-950 rounded-[10px] p-1">
        {(['bike', 'service'] as Tab[]).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`flex-1 py-2 px-3 rounded-lg text-[12px] font-medium transition-all capitalize ${
              tab === t
                ? 'bg-carbon-800 text-emerald'
                : 'text-muted hover:text-gray-300'
            }`}
          >
            {t === 'service' ? 'Service' : 'Bike'}
          </button>
        ))}
      </div>

      {/* Tab content */}
      <div className="flex-1 overflow-y-auto">
        {tab === 'bike' && (
          <div>
            <h3 className="text-[11px] text-muted uppercase tracking-[0.8px] font-semibold mb-3">
              Components
            </h3>
            {loadingContext ? (
              <div className="space-y-2">
                {[...Array(4)].map((_, i) => (
                  <div key={i} className="h-14 bg-carbon-800 rounded-lg animate-pulse" />
                ))}
              </div>
            ) : components.length === 0 ? (
              <p className="text-sm text-muted">No components found.</p>
            ) : (
              components.map((c) => (
                <div
                  key={c.component_id}
                  className="px-3 py-2.5 bg-carbon-800 rounded-lg mb-1.5 border-l-[3px] border-emerald-dark"
                >
                  <div className="text-[10px] text-emerald uppercase tracking-[0.5px] mb-0.5">
                    {c.category}
                  </div>
                  <div className="text-sm text-gray-300">
                    {c.brand} {c.model}
                  </div>
                </div>
              ))
            )}
          </div>
        )}

        {tab === 'service' && (
          <div>
            <h3 className="text-[11px] text-muted uppercase tracking-[0.8px] font-semibold mb-3">
              Upcoming Service
            </h3>
            {loadingContext ? (
              <div className="space-y-2">
                {[...Array(3)].map((_, i) => (
                  <div key={i} className="h-16 bg-carbon-800 rounded-lg animate-pulse" />
                ))}
              </div>
            ) : upcoming.length === 0 ? (
              <p className="text-sm text-muted mb-4">No upcoming service.</p>
            ) : (
              upcoming.map((m) => (
                <MaintenanceCard key={m.task_id} item={m} />
              ))
            )}

            {done.length > 0 && (
              <>
                <h3 className="text-[11px] text-muted uppercase tracking-[0.8px] font-semibold mb-3 mt-5">
                  Recently Completed
                </h3>
                {done.map((m) => (
                  <MaintenanceCard key={m.task_id} item={m} />
                ))}
              </>
            )}
          </div>
        )}
      </div>

      {/* New conversation */}
      <button
        onClick={() => window.location.reload()}
        className="mt-4 py-2.5 bg-emerald-deep hover:bg-emerald-dark text-gray-100 text-sm font-medium rounded-lg transition-all hover:-translate-y-px"
      >
        + New Conversation
      </button>
    </aside>
  )
}

function MaintenanceCard({ item }: { item: MaintenanceItem }) {
  const borderColor =
    item.status === 'overdue'
      ? 'border-red-600'
      : item.status === 'done'
      ? 'border-emerald-dark'
      : 'border-amber-600'

  const dueColor =
    item.status === 'overdue'
      ? 'text-red-500'
      : item.status === 'done'
      ? 'text-emerald-dark'
      : 'text-amber-500'

  return (
    <div className={`px-3 py-3 bg-carbon-800 rounded-lg mb-2 border-l-[3px] ${borderColor}`}>
      <div className="text-sm text-gray-200 font-medium mb-1">{item.task_name}</div>
      <div className="flex justify-between text-[11px] text-muted">
        <span>{item.interval_description}</span>
        <span className={dueColor}>{item.due_label}</span>
      </div>
      <span className="inline-block mt-1.5 px-1.5 py-0.5 bg-carbon-700 rounded text-[10px] text-emerald">
        {item.component_name}
      </span>
    </div>
  )
}
