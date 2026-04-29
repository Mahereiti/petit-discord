defmodule MiniDiscord.ClientHandler do
  require Logger

  def start(socket) do
    :gen_tcp.send(socket, "Bienvenue sur MiniDiscord!\r\n")
    pseudo = choisir_pseudo(socket)

    :gen_tcp.send(socket, "Salons disponibles : #{salons_dispo()}\r\n")
    :gen_tcp.send(socket, "Rejoins un salon (ex: general) : ")
    {:ok, salon} = :gen_tcp.recv(socket, 0)
    salon = String.trim(salon)

    rejoindre_salon(socket, pseudo, salon)
  end

  defp choisir_pseudo(socket) do
    :gen_tcp.send(socket, "Entre ton pseudo : ")
    {:ok, pseudo} = :gen_tcp.recv(socket, 0)
    pseudo = String.trim(pseudo)
    # TODO : Si pseudo_disponible?(pseudo) -> reserver_pseudo(pseudo) et retourner pseudo
    # TODO : Sinon -> envoyer un message d'erreur et rappeler choisir_pseudo(socket)
    if pseudo_disponible?(pseudo) do
      reserver_pseudo(pseudo)
      pseudo
    else
      :gen_tcp.send(socket, "ERREUR : Pseudo déjà pris...")
      choisir_pseudo(socket)
    end
  end

  defp rejoindre_salon(socket, pseudo, salon) do
    case Registry.lookup(MiniDiscord.Registry, salon) do
      [] ->
        DynamicSupervisor.start_child(
          MiniDiscord.SalonSupervisor,
          {MiniDiscord.Salon, salon})
      _ -> :ok
    end

    case MiniDiscord.Salon.rejoindre(salon, self()) do
      :ok ->
        MiniDiscord.Salon.broadcast(salon, "📢 #{pseudo} a rejoint ##{salon}\r\n")
        :gen_tcp.send(socket, "Tu es dans ##{salon} — écris tes messages !\r\n")
        loop(socket, pseudo, salon)

      {:error, :password_required} ->
        :gen_tcp.send(socket, "Mot de passe : ")
        {:ok, pwd} = :gen_tcp.recv(socket, 0)

        case MiniDiscord.Salon.rejoindre_avec_password(salon, self(), String.trim(pwd)) do
          :ok ->
            MiniDiscord.Salon.broadcast(salon, "📢 #{pseudo} a rejoint ##{salon}\r\n")
            :gen_tcp.send(socket, "Tu es dans ##{salon} — écris tes messages !\r\n")
            loop(socket, pseudo, salon)

          _ ->
            :gen_tcp.send(socket, "Mot de passe incorrect.\r\n")
            rejoindre_salon(socket, pseudo, salon)
        end
    end

    loop(socket, pseudo, salon)
  end

  defp loop(socket, pseudo, salon) do
    receive do
      {:message, msg} ->
        :gen_tcp.send(socket, msg)
    after 0 -> :ok
    end

    case :gen_tcp.recv(socket, 0, 100) do
      {:ok, msg} ->
        msg = String.trim(msg)
        # TODO : Si msg commence par "/" -> gérer_commande(socket, pseudo, salon, msg)
        # TODO : Sinon -> broadcast normal
        if String.starts_with?(msg, "/") do
          gerer_commande(socket, pseudo, salon, msg)
        else
          MiniDiscord.Salon.broadcast(salon, "[#{pseudo}] #{msg}\r\n")
        end
        loop(socket, pseudo, salon)

      {:error, :timeout} ->
        loop(socket, pseudo, salon)

      {:error, reason} ->
        Logger.info("Client déconnecté : #{inspect(reason)}")
        MiniDiscord.Salon.broadcast(salon, "👋 #{pseudo} a quitté ##{salon}\r\n")
        MiniDiscord.Salon.quitter(salon, self())
    end
  end

  defp gerer_commande(socket, pseudo, salon, commande) do
    case commande do
      # TODO : "/list" -> envoyer la liste des salons avec MiniDiscord.Salon.lister()
      "/list" ->
        salons = MiniDiscord.Salon.lister()
        :gen_tcp.send(socket, "Salons disponibles : #{Enum.join(salons, ", ")}\r\n")

      # TODO : "/quit" -> déconnecter proprement le client
      "/quit" ->
          :gen_tcp.send(socket, "Au revoir!")
          liberer_pseudo(pseudo)
          MiniDiscord.Salon.quitter(salon, self())
          :gen_tcp.close(socket)

      # TODO : "/join <nom>" -> quitter le salon actuel et rejoindre le nouveau
      # TODO : _ -> envoyer "Commande inconnue"
      _ ->
        if String.starts_with?(commande, "/join ") do
          [_cmd, nom] = String.split(commande, " ", parts: 2)
          MiniDiscord.Salon.quitter(salon, self())
          rejoindre_salon(socket, pseudo, nom)
        else
          :gen_tcp.send(socket, "Commande inconnue\r\n")
        end
    end
  end

  defp salons_dispo do
    case MiniDiscord.Salon.lister() do
      [] -> "aucun (tu seras le premier !)"
      salons -> Enum.join(salons, ", ")
    end
  end

  # 3.1
  defp pseudo_disponible?(pseudo) do
    # TODO : Vérifier avec :ets.lookup(:pseudos, pseudo) si le pseudo est déjà pris
    # TODO : Retourner true si disponible, false sinon
    :ets.lookup(:pseudos, pseudo) == []
  end

  defp reserver_pseudo(pseudo) do
    # TODO : Insérer dans :ets avec :ets.insert(:pseudos, {pseudo, self()})
    :ets.insert(:pseudos, {pseudo, self()})
  end

  defp liberer_pseudo(pseudo) do
    # TODO : Supprimer de :ets avec :ets.delete(:pseudos, pseudo)
    :ets.delete(:pseudos, pseudo)
  end
end
