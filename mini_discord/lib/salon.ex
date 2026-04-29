defmodule MiniDiscord.Salon do
  use GenServer

  def start_link(name) do
    GenServer.start_link(__MODULE__, %{name: name, clients: [], historique: [], password: nil},
      name: via(name))
  end

  def rejoindre(salon, pid), do: GenServer.call(via(salon), {:rejoindre, pid})
  def quitter(salon, pid),   do: GenServer.call(via(salon), {:quitter, pid})
  def broadcast(salon, msg), do: GenServer.cast(via(salon), {:broadcast, msg})
  # Nouvelle API :
  def definir_password(salon, password), do: GenServer.call(via(salon), {:password, password})

  def lister do
    # TODO : Utiliser Registry.select/2 pour récupérer toutes les clés du Registry
    # TODO : Retourner la liste des noms de salons
    Registry.select(MiniDiscord.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  def init(state), do: {:ok, state}


  def rejoindre_avec_password(salon, pid, password) do
    GenServer.call(via(salon), {:rejoindre_password, pid, password})
  end
  
  # TODO : Implémenter handle_call({:password, password}) pour stocker le mot de passe hashé
  # TODO : Utiliser :crypto.hash(:sha256, password) pour hasher
  def handle_call({:password, password}, _from, state) do
    nouvel_etat = %{state | password: :crypto.hash(:sha256, password)}
    {:reply, :ok, nouvel_etat}
  end

  # TODO : Lors du rejoindre, vérifier le mot de passe si state.password != nil
  def handle_call({:rejoindre, pid}, _from, state) do
    if state.password == nil do
        # TODO : Monitorer le pid avec Process.monitor/1
        # TODO : Envoyer l'historique au nouveau client dans handle_call({:rejoindre, pid})
        # TODO : Retourner {:reply, :ok, nouvel_état} avec pid ajouté à state.clients
        Process.monitor(pid)
        Enum.each(Enum.reverse(state.historique), fn msg -> send(pid, {:message, msg}) end)
        nouvel_etat = %{state | clients: [pid | state.clients]}
        {:reply, :ok, nouvel_etat}
    else
        {:reply, {:error, :password_required}, state}
    end
  end

  def handle_call({:rejoindre_password, pid, pwd}, _from, state) do
    if :crypto.hash(:sha256, pwd) == state.password do
      Process.monitor(pid)
      Enum.each(Enum.reverse(state.historique), fn msg -> send(pid, {:message, msg}) end)
      nouvel_etat = %{state | clients: [pid | state.clients]}
      {:reply, :ok, nouvel_etat}
    else
      {:reply, {:error, :bad_password}, state}
    end
  end

  def handle_call({:quitter, pid}, _from, state) do
    # TODO : Retourner {:reply, :ok, nouvel_état} avec pid retiré de state.clients
    nouvel_etat = %{state | clients: List.delete(state.clients, pid)}
    {:reply, :ok, nouvel_etat}
  end

  def handle_cast({:broadcast, msg}, state) do
    # TODO : Ajouter msg à state.historique (garder max 10 messages avec Enum.take/2)
    new_historique = [msg | state.historique] |> Enum.take(10)
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
