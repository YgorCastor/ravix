defmodule Ravix.Helpers.Certs do
  def key_from_b64_to_der(key) do
    decoded_pem = Base.decode64!(key)
    [{key, der, _}] = :public_key.pem_decode(decoded_pem)
    {key, der}
  end

  def cert_from_b64_to_der(cert) do
    decoded_pem = Base.decode64!(cert)
    [{:Certificate, der, _}] = :public_key.pem_decode(decoded_pem)
    der
  end
end
