defmodule Ravix.Test.OptimisticLockStore do
  @moduledoc false
  use Ravix.Documents.Store, otp_app: :ravix
end

defmodule Ravix.Test.NonRetryableStore do
  @moduledoc false
  use Ravix.Documents.Store, otp_app: :ravix
end

defmodule Ravix.Test.ClusteredStore do
  @moduledoc false
  use Ravix.Documents.Store, otp_app: :ravix
end

defmodule Ravix.Test.Store do
  @moduledoc false
  use Ravix.Documents.Store, otp_app: :ravix
end

defmodule Ravix.Test.RandomStore do
  @moduledoc false
  use Ravix.Documents.Store, otp_app: :ravix
end

defmodule Ravix.Test.StoreInvalid do
  @moduledoc false
  use Ravix.Documents.Store, otp_app: :ravix
end

defmodule Ravix.Test.CachedStore do
  @moduledoc false
  use Ravix.Documents.Store, otp_app: :ravix
end
