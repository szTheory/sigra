ExUnit.start()

# Define Mox mocks for Sigra.Auth tests
Mox.defmock(Sigra.MockRepo, for: Sigra.MockRepo.Behaviour)
Mox.defmock(Sigra.MockRateLimiter, for: Sigra.RateLimiter)
Mox.defmock(Sigra.MockMailer, for: Sigra.Mailer)
Mox.defmock(Sigra.MockSessionStore, for: Sigra.SessionStore)
Mox.defmock(Sigra.MockGeoIP, for: Sigra.GeoIP)
Mox.defmock(Sigra.MockEmailTemplates, for: Sigra.EmailTemplates)
