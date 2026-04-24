defmodule MiniDiscord.Salon do
  use GenServer

  def start_link(name) do
    # Dans l'état du Salon, ajoutez : %{name: name, clients: [], historique: []}
    GenServer.start_link(__MODULE__, %{name: name, clients: [], historique: []},
      name: via(name))
  end

  def rejoindre(salon, pid), do: GenServer.call(via(salon), {:rejoindre, pid})
  def quitter(salon, pid),   do: GenServer.call(via(salon), {:quitter, pid})
  def broadcast(salon, msg), do: GenServer.cast(via(salon), {:broadcast, msg})
  def lister do
    Registry.select(MiniDiscord.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  def init(state), do: {:ok, state}

  def handle_call({:rejoindre, pid}, _from, state) do
    # TODO : Monitorer le pid avec Process.monitor/1
    Process.monitor(pid)
    # TODO : Envoyer l'historique au nouveau client dans handle_call({:rejoindre, pid})
    Enum.each(state.historique, fn msg -> send(msg, {:message, msg}) end)
    # TODO : Retourner {:reply, :ok, nouvel_état} avec pid ajouté à state.clients
    nouvel_etat = %{state | clients: [pid | state.clients]}
    {:reply, :ok, nouvel_etat}
  end

  def handle_call({:quitter, pid}, _from, state) do
    # TODO : Retourner {:reply, :ok, nouvel_état} avec pid retiré de state.clients
    nouvel_etat = %{state | clients: List.delete(state.clients, pid)}
    {:reply, :ok, nouvel_etat}
  end

  def handle_cast({:broadcast, msg}, state) do
    # TODO : Ajouter msg à state.historique (garder max 10 messages avec Enum.take/2)
    new_historique = Enum.take([state.historique | msg], 10)
    new_state = %{state | historique: new_historique}

    # TODO : Envoyer {:message, msg} à chaque pid dans state.clients
    Enum.each(state.clients, fn pid -> send(pid, {:message, msg}) end)
    # TODO : Retourner {:noreply, state}
    {:noreply, new_state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # TODO : Retirer pid de state.clients (il s'est déconnecté)
    nouvel_etat = %{state | clients: List.delete(state.clients, pid)}
    # TODO : Retourner {:noreply, nouvel_état}
    {:noreply, nouvel_etat}
  end

  defp via(name), do: {:via, Registry, {MiniDiscord.Registry, name}}
end
