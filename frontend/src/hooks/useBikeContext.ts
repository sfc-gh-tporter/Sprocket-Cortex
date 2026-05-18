import { useState, useEffect } from 'react'
import { Bike, Component, MaintenanceItem } from '../types'

export function useBikeContext() {
  const [bikes, setBikes] = useState<Bike[]>([])
  const [selectedBikeId, setSelectedBikeId] = useState<number | null>(null)
  const [components, setComponents] = useState<Component[]>([])
  const [maintenance, setMaintenance] = useState<MaintenanceItem[]>([])
  const [loadingBikes, setLoadingBikes] = useState(true)
  const [loadingContext, setLoadingContext] = useState(false)

  useEffect(() => {
    fetch('/api/bikes')
      .then((r) => r.json())
      .then((data: Bike[]) => {
        setBikes(data)
        if (data.length > 0) setSelectedBikeId(data[0].bike_id)
      })
      .catch(console.error)
      .finally(() => setLoadingBikes(false))
  }, [])

  useEffect(() => {
    if (selectedBikeId == null) return
    setLoadingContext(true)
    fetch(`/api/bikes/${selectedBikeId}/context`)
      .then((r) => r.json())
      .then((data: { components: Component[]; maintenance: MaintenanceItem[] }) => {
        setComponents(data.components ?? [])
        setMaintenance(data.maintenance ?? [])
      })
      .catch(console.error)
      .finally(() => setLoadingContext(false))
  }, [selectedBikeId])

  return {
    bikes,
    selectedBikeId,
    setSelectedBikeId,
    components,
    maintenance,
    loadingBikes,
    loadingContext,
  }
}
